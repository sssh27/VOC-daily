import 'dart:convert';
import 'dart:math';

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

  /// 【v5】補位機制:再從倉庫(isIntroduced == false)引入 1 張新卡,接在
  /// 認識卡佇列最後面。倉庫沒有卡片時回傳 null,呼叫端不需要另外檢查
  /// notIntroducedCount(),直接看回傳值是不是 null 即可。見 SPEC.md 6.4
  /// 「額度補位機制」。
  Future<Card?> replenishOneNewCard({DateTime? now}) async {
    final today = _startOfDay(now ?? DateTime.now());
    final candidate = await (_db.select(_db.cards)
          ..where((c) => c.isIntroduced.equals(false))
          ..limit(1))
        .getSingleOrNull();
    if (candidate == null) return null;

    await (_db.update(_db.cards)..where((c) => c.id.equals(candidate.id)))
        .write(
      CardsCompanion(
        isIntroduced: const Value(true),
        dueDate: Value(today),
      ),
    );
    return (_db.select(_db.cards)..where((c) => c.id.equals(candidate.id)))
        .getSingle();
  }

  /// 倉庫裡還有多少張未引入的卡片(用來判斷是否要提示「單字庫快用完了」)。
  Future<int> notIntroducedCount() async {
    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.isIntroduced.equals(false));
    final row = await query.getSingle();
    return row.read(_db.cards.id.count()) ?? 0;
  }

  /// 【v7】累計字數:`isIntroduced == true` 的筆數(見 SPEC.md 12.2)。
  /// 單調遞增,包含按過「我會了」的字,不計算掌握率或任何比值。
  Future<int> introducedCount() async {
    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.id.count()])
      ..where(_db.cards.isIntroduced.equals(true));
    final row = await query.getSingle();
    return row.read(_db.cards.id.count()) ?? 0;
  }

  // ---------------------------------------------------------------------
  // 【v7】AppSettings(里程碑進度,見 SPEC.md 12.3)
  // ---------------------------------------------------------------------

  static const _celebratedMilestoneKey = 'celebrated_milestone';

  /// key 不存在時回傳 null,不 crash。
  Future<String?> getSetting(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  /// 目前已慶祝過的最高里程碑門檻。key 不存在時預設 0(見 SPEC.md 12.3)。
  Future<int> celebratedMilestone() async {
    final raw = await getSetting(_celebratedMilestoneKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> setCelebratedMilestone(int value) {
    return setSetting(_celebratedMilestoneKey, value.toString());
  }

  // ---------------------------------------------------------------------
  // 6.4 學習佇列(v4:新字 + 到期字合併)
  // ---------------------------------------------------------------------

  /// 新字:isIntroduced == true AND lastReviewed == null,依 id 由小到大。
  /// 這些卡片今天只會以「認識卡」出現一次,不會被考。
  Future<List<Card>> newCards() {
    return (_db.select(_db.cards)
          ..where((c) =>
              c.isIntroduced.equals(true) & c.lastReviewed.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
  }

  /// 到期字:isIntroduced == true AND lastReviewed != null AND
  /// dueDate <= 今天 23:59:59,依 dueDate 由舊到新排序。
  Future<List<Card>> dueForStudyCards({DateTime? now}) {
    final endOfToday = _endOfDay(now ?? DateTime.now());
    return (_db.select(_db.cards)
          ..where((c) =>
              c.isIntroduced.equals(true) &
              c.lastReviewed.isNotNull() &
              c.dueDate.isSmallerOrEqualValue(endOfToday))
          ..orderBy([(c) => OrderingTerm.asc(c.dueDate)]))
        .get();
  }

  /// 學習佇列 = 新字(前)+ 到期字(後)。見 SPEC.md 6.4「佇列組成與順序」。
  Future<List<Card>> studyQueue({DateTime? now}) async {
    final intro = await newCards();
    final due = await dueForStudyCards(now: now);
    return [...intro, ...due];
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

  /// 全部卡片(不分牌組/是否已引入)。
  Future<List<Card>> allCards() => _db.select(_db.cards).get();

  static List<String> _decodeAvoidWith(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // 壞掉的資料就當作沒有限制,不報錯(見 SPEC.md 0:「不確定時別猜」的
      // 反面 —— 這裡資料格式錯誤不是邏輯不確定,不影響其他功能,容錯即可)。
    }
    return const [];
  }

  /// 四選一測驗的干擾選項(meaning)。依 SPEC.md 6.4「干擾項選取規則」:
  /// 1. 優先從同一個 deck 挑
  /// 2. 排除 avoidWith 標記的字(雙向 —— 這張卡列了對方,或對方列了這張卡,
  ///    都要排除)
  /// 3. 同 deck 湊不滿 [count] 個時,回退到全庫隨機湊滿
  ///
  /// 回傳的 meaning 不重複、不含 [card] 自己的 meaning。資料庫太小的話,
  /// 回傳數量可能小於 [count],呼叫端(review_screen.dart)要能處理選項
  /// 不足 3 個的情況。
  Future<List<String>> distractorMeaningsFor(Card card, {int count = 3}) async {
    final avoidWords = {card.word, ..._decodeAvoidWith(card.avoidWith)};
    final random = Random();

    bool isExcluded(Card other) {
      if (avoidWords.contains(other.word)) return true;
      if (_decodeAvoidWith(other.avoidWith).contains(card.word)) return true;
      return false;
    }

    final picked = <String>{};

    final sameDeck = await (_db.select(_db.cards)
          ..where((c) => c.deckId.equals(card.deckId)))
        .get();
    final sameDeckCandidates = sameDeck
        .where((c) => c.id != card.id && c.meaning != card.meaning && !isExcluded(c))
        .toList()
      ..shuffle(random);
    for (final c in sameDeckCandidates) {
      if (picked.length >= count) break;
      picked.add(c.meaning);
    }

    if (picked.length < count) {
      final allCards = await _db.select(_db.cards).get();
      final globalCandidates = allCards
          .where((c) =>
              c.id != card.id &&
              c.meaning != card.meaning &&
              !picked.contains(c.meaning) &&
              !isExcluded(c))
          .toList()
        ..shuffle(random);
      for (final c in globalCandidates) {
        if (picked.length >= count) break;
        picked.add(c.meaning);
      }
    }

    return picked.toList();
  }

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

  /// 【v6】依名稱判斷牌組是否已存在(見 SPEC.md 7.2「多牌組載入」)。
  /// 用來讓 `DeckLoader` 逐一判斷該匯入哪些內建牌組,而不是整庫是否為空。
  Future<bool> deckExistsByName(String name) async {
    final query = _db.selectOnly(_db.decks)
      ..addColumns([_db.decks.id.count()])
      ..where(_db.decks.name.equals(name));
    final row = await query.getSingle();
    return (row.read(_db.decks.id.count()) ?? 0) > 0;
  }

  /// 建立新牌組並寫入卡片,isIntroduced 全部為 false(見 6.6)。
  /// [avoidWith] 是選填的四選一排除名單(見 6.4),沒有就傳空陣列。
  /// [exampleMatch]【v6】是選填的例句粗體比對字串(見 6.3),沒有就傳 null
  /// (AI 生成的卡片一律傳 null)。
  Future<int> createDeckWithCards({
    required String name,
    required String topic,
    required List<({
      String word,
      String phonetic,
      String meaning,
      String example,
      String exampleZh,
      List<String> avoidWith,
      String? exampleMatch,
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
              avoidWith: Value(
                c.avoidWith.isEmpty ? null : jsonEncode(c.avoidWith),
              ),
              exampleMatch: Value(c.exampleMatch),
            ),
          );
    }
    return deckId;
  }
}
