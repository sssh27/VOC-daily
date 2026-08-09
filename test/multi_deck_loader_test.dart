import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/data/card_repository.dart';
import 'package:vocab_srs_app/data/database.dart';
import 'package:vocab_srs_app/logic/scheduler.dart';
import 'package:vocab_srs_app/services/deck_loader.dart';

/// 涵蓋 DeckLoader.importMissingDecks() 的多牌組載入邏輯(SPEC.md 7.2,v6):
/// 依名稱判斷是否已存在、已存在的不覆蓋不更新、單一牌組失敗不影響其他牌組。
///
/// 用真正的 asset 路徑(`assets/decks/starter_deck.json` /
/// `assets/decks/cruise_travel.json`),因為它們已經在 `pubspec.yaml` 註冊,
/// `flutter_test` 的 asset bundle 可以直接讀到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CardRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('deckExistsByName:不存在的名稱回傳 false', () async {
    expect(await repo.deckExistsByName('入門常用字'), isFalse);
  });

  test('deckExistsByName:建立牌組後回傳 true', () async {
    await repo.createDeckWithCards(
      name: '入門常用字',
      topic: '',
      cards: const [],
    );
    expect(await repo.deckExistsByName('入門常用字'), isTrue);
  });

  test('空資料庫時,兩個內建牌組都會被匯入', () async {
    await DeckLoader(repo).importMissingDecks();

    expect(await repo.deckExistsByName('入門常用字'), isTrue);
    expect(await repo.deckExistsByName('郵輪與旅遊實用'), isTrue);

    final cards = await repo.allCards();
    // 入門常用字 30 張 + 郵輪與旅遊實用 166 張
    expect(cards.length, 30 + 166);
  });

  test('已有「入門常用字」時,只會匯入「郵輪與旅遊實用」,原牌組進度不變', () async {
    final existingDeckId = await repo.createDeckWithCards(
      name: '入門常用字',
      topic: '',
      cards: const [
        (
          word: 'hello',
          phonetic: '',
          meaning: '哈囉',
          example: '',
          exampleZh: '',
          avoidWith: <String>[],
          exampleMatch: null,
        ),
      ],
    );
    // 模擬使用者已經學過這張卡。
    final existingCards = await repo.allCards();
    final existingCard = existingCards.single;
    await repo.submitReview(
      existingCard.id,
      reviewCard(
        ScheduleState(
          easiness: existingCard.easiness,
          interval: existingCard.interval,
          repetitions: existingCard.repetitions,
          dueDate: existingCard.dueDate,
        ),
        4,
      ),
    );

    await DeckLoader(repo).importMissingDecks();

    expect(await repo.deckExistsByName('入門常用字'), isTrue);
    expect(await repo.deckExistsByName('郵輪與旅遊實用'), isTrue);

    // 原本那張卡沒有被覆蓋:牌組裡仍然只有 1 張(我們手動塞的假資料),
    // 不是被 starter_deck.json 的 30 張蓋掉或疊加。
    final cardsInExistingDeck =
        (await repo.allCards()).where((c) => c.deckId == existingDeckId);
    expect(cardsInExistingDeck.length, 1);
    expect(cardsInExistingDeck.single.word, 'hello');
    expect(cardsInExistingDeck.single.lastReviewed, isNotNull);

    // 郵輪牌組正常匯入 166 張。
    final progress = await repo.deckProgress(
      (await repo.allDecks())
          .firstWhere((d) => d.name == '郵輪與旅遊實用')
          .id,
    );
    expect(progress.$2, 166); // total
  });

  test('兩個牌組都已存在時,不重複匯入,卡片總數不變', () async {
    await DeckLoader(repo).importMissingDecks();
    final countAfterFirst = (await repo.allCards()).length;

    await DeckLoader(repo).importMissingDecks();
    final countAfterSecond = (await repo.allCards()).length;

    expect(countAfterSecond, countAfterFirst);
  });

  test('asset 路徑不存在時不會 crash,其他牌組照常匯入', () async {
    await DeckLoader(
      repo,
      assetPaths: const [
        'assets/decks/does_not_exist.json',
        'assets/decks/starter_deck.json',
      ],
    ).importMissingDecks();

    expect(await repo.deckExistsByName('入門常用字'), isTrue);
  });
}
