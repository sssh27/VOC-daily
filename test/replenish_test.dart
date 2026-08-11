import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/data/card_repository.dart';
import 'package:vocab_srs_app/data/database.dart';

/// 涵蓋 CardRepository.replenishOneNewCard()(SPEC.md 6.4「額度補位機制」,
/// v5):按「我會了」時從倉庫再引入 1 張,倉庫空時回傳 null、不 crash。
void main() {
  late AppDatabase db;
  late CardRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertDeck(String name) {
    return db.into(db.decks).insert(DecksCompanion.insert(name: name));
  }

  Future<void> insertCard(
    int deckId,
    String word, {
    bool isIntroduced = false,
  }) {
    return db.into(db.cards).insert(
          CardsCompanion.insert(
            deckId: deckId,
            word: word,
            meaning: '$word 的意思',
            isIntroduced: Value(isIntroduced),
          ),
        );
  }

  test('倉庫有未引入卡片時,補位會引入 1 張並回傳它', () async {
    final deckId = await insertDeck('A');
    await insertCard(deckId, 'already', isIntroduced: true);
    await insertCard(deckId, 'warehouse1');
    await insertCard(deckId, 'warehouse2');

    final result = await repo.replenishOneNewCard();

    expect(result, isNotNull);
    expect(result!.isIntroduced, isTrue);
    expect(await repo.notIntroducedCount(), 1);
  });

  test('補位後的卡片 dueDate 設為今天(與 introduceNewCards 行為一致)', () async {
    final deckId = await insertDeck('A');
    await insertCard(deckId, 'warehouse1');
    final now = DateTime(2026, 3, 15);

    final result = await repo.replenishOneNewCard(now: now);

    expect(result!.dueDate, DateTime(2026, 3, 15));
  });

  test('倉庫已空時,補位回傳 null,不會 crash', () async {
    final deckId = await insertDeck('A');
    await insertCard(deckId, 'already', isIntroduced: true);

    final result = await repo.replenishOneNewCard();

    expect(result, isNull);
  });

  test('連續補位:每次只引入 1 張,直到倉庫用盡回傳 null', () async {
    final deckId = await insertDeck('A');
    await insertCard(deckId, 'w1');
    await insertCard(deckId, 'w2');

    final first = await repo.replenishOneNewCard();
    final second = await repo.replenishOneNewCard();
    final third = await repo.replenishOneNewCard();

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.id, isNot(second!.id));
    expect(third, isNull);
  });
}
