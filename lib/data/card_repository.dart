import 'package:drift/drift.dart';
import '../logic/scheduler.dart';
import 'database.dart';

/// 把畫面層需要的所有查詢封裝起來,畫面層不直接碰 Drift。
///
/// 「今天」一律以本機時間的零點/23:59:59 為邊界,對應 SPEC.md 第 5 節。
class CardRepository {
  CardRepository(this._db);

  final AppDatabase _db;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  // ---------------------------------------------------------------------
  // 5.1 積壓量
  // ---------------------------------------------------------------------

  /// isIntroduced == true AND dueDate < 今天 00:00:00
  Future<int> backlogCount({DateTime? now}) async {
    final today = _startOfDay(now ?? DateTime.now());
    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.isIntroduced.equals(true) &
          _db.cards.dueDate.isSmallerThanValue(today));
    final row = await query.getSingle();
    return row.read(_db.cards.id.count()) ?? 0;
  }

  // ---------------------------------------------------------------------
  // 每日拉霸紀錄
  // ---------------------------------------------------------------------

  /// 今天是否已經拉過霸。
  Future<DailyRoll?> todaysRoll({DateTime? now}) async {
    final today = _startOfDay(now ?? DateTime.now());
    return (_db.select(_db.dailyRolls)
          ..where((t) => t.rollDate.equals(today)))
        .getSingleOrNull();
  }

  /// 寫入今天的拉霸紀錄(5.5 步驟 3)。若今天已經拉過會丟例外,避免重複拉霸。
  Future<void> recordRoll({
    required int quota,
    required bool wasCapped,
    DateTime? now,
  }) async {
    final today = _startOfDay(now ?? DateTime.now());
    final existing = await todaysRoll(now: today);
    if (existing != null) {
      throw StateError('今天已經拉過霸了');
    }
    await _db.into(_db.dailyRolls).insert(
          DailyRollsCompanion.insert(
            rollDate: today,
            quota: quota,
            wasCapped: Value(wasCapped),
          ),
        );
  }

  // ---------------------------------------------------------------------
  // 5.5 引入新卡
  // ---------------------------------------------------------------------

  /// 從尚未引入的卡片中挑最多 [quota] 張設為已引入。
  /// 回傳實際被引入的張數(倉庫不夠時會小於 quota)。
  Future<int> introduceNewCards(int quota, {DateTime? now}) async {
    if (quota <= 0) return 0;
    final today = _startOfDay(now ?? DateTime.now());

    final candidates = await (_db.select(_db.cards)
          ..where((c) => c.isIntroduced.equals(false))
          ..limit(quota))
        .get();

    for (final card in candidates) {
      await (_db.update(_db.cards)..where((c) => c.id.equals(card.id))).write(
        CardsCompanion(
          isIntroduced: const Value(true),
          dueDate: Value(today),
        ),
      );
    }
    return candidates.length;
  }

  /// 倉庫裡還有多少張未引入的卡片(用來判斷是否要提示「單字庫快用完了」)。
  Future<int> notIntroducedCount() async {
    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.isIntroduced.equals(false));
    final row = await query.getSingle();
    return row.read(_db.cards.id.count()) ?? 0;
  }

  // ---------------------------------------------------------------------
  // 5.6 複習佇列
  // ---------------------------------------------------------------------

  /// isIntroduced == true AND dueDate <= 今天 23:59:59,依 dueDate 由舊到新排序。
  Future<List<Card>> reviewQueue({DateTime? now}) {
    final endOfToday = _endOfDay(now ?? DateTime.now());
    return (_db.select(_db.cards)
          ..where((c) =>
              c.isIntroduced.equals(true) &
              c.dueDate.isSmallerOrEqualValue(endOfToday))
          ..orderBy([(c) => OrderingTerm.asc(c.dueDate)]))
        .get();
  }

  /// 待複習張數(僅供首頁顯示中性數字,見 6.1)。
  Future<int> dueCount({DateTime? now}) async {
    final endOfToday = _endOfDay(now ?? DateTime.now());
    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.isIntroduced.equals(true) &
          _db.cards.dueDate.isSmallerOrEqualValue(endOfToday));
    final row = await query.getSingle();
    return row.read(_db.cards.id.count()) ?? 0;
  }

  /// 用 lib/logic/scheduler.dart 的 reviewCard() 結果寫回資料庫。
  Future<void> submitReview(
    int cardId,
    ScheduleState newState, {
    DateTime? now,
  }) async {
    await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        easiness: Value(newState.easiness),
        interval: Value(newState.interval),
        repetitions: Value(newState.repetitions),
        dueDate: Value(newState.dueDate),
        lastReviewed: Value(now ?? DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 牌組
  // ---------------------------------------------------------------------

  Future<List<Deck>> allDecks() => _db.select(_db.decks).get();

  /// 全部卡片(不分牌組/是否已引入),用來當四選一測驗的干擾選項來源。
  Future<List<Card>> allCards() => _db.select(_db.cards).get();

  /// 該牌組已學(isIntroduced==true)與總卡片數。
  Future<(int learned, int total)> deckProgress(int deckId) async {
    final totalQuery = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.deckId.equals(deckId));
    final learnedQuery = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.deckId.equals(deckId) &
          _db.cards.isIntroduced.equals(true));
    final total =
        (await totalQuery.getSingle()).read(_db.cards.id.count()) ?? 0;
    final learned =
        (await learnedQuery.getSingle()).read(_db.cards.id.count()) ?? 0;
    return (learned, total);
  }

  Future<bool> hasAnyDeck() async {
    final query = _db.selectOnly(_db.decks)
      ..addColumns([_db.decks.id.count()]);
    final row = await query.getSingle();
    return (row.read(_db.decks.id.count()) ?? 0) > 0;
  }

  /// 建立新牌組並寫入卡片,isIntroduced 全部為 false(見 6.6)。
  Future<int> createDeckWithCards({
    required String name,
    required String topic,
    required List<({
      String word,
      String phonetic,
      String meaning,
      String example,
      String exampleZh,
    })> cards,
  }) async {
    final deckId = await _db.into(_db.decks).insert(
          DecksCompanion.insert(name: name, topic: Value(topic)),
        );
    for (final c in cards) {
      await _db.into(_db.cards).insert(
            CardsCompanion.insert(
              deckId: deckId,
              word: c.word,
              phonetic: Value(c.phonetic),
              meaning: c.meaning,
              example: Value(c.example),
              exampleZh: Value(c.exampleZh),
              isIntroduced: const Value(false),
            ),
          );
    }
    return deckId;
  }
}
