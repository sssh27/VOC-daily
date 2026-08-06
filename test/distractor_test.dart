import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/data/card_repository.dart';
import 'package:vocab_srs_app/data/database.dart';

/// 涵蓋 CardRepository.distractorMeaningsFor() 的干擾項選取邏輯(SPEC.md
/// 6.4「干擾項選取規則」):同 deck 優先、avoidWith 雙向排除、回退全庫、
/// 不重複、資料不足時不崩潰。
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

  Future<Card> insertCard(
    int deckId,
    String word,
    String meaning, {
    List<String>? avoidWith,
  }) async {
    final id = await db.into(db.cards).insert(
          CardsCompanion.insert(
            deckId: deckId,
            word: word,
            meaning: meaning,
            avoidWith: Value(
              avoidWith == null || avoidWith.isEmpty
                  ? null
                  : jsonEncode(avoidWith),
            ),
          ),
        );
    return (db.select(db.cards)..where((c) => c.id.equals(id))).getSingle();
  }

  test('同 deck 有足夠卡片時,3 個 distractor 全部來自同 deck', () async {
    final deckA = await insertDeck('A');
    final deckB = await insertDeck('B');
    final target = await insertCard(deckA, 'target', '目標');
    await insertCard(deckA, 'a1', '同deck1');
    await insertCard(deckA, 'a2', '同deck2');
    await insertCard(deckA, 'a3', '同deck3');
    await insertCard(deckA, 'a4', '同deck4');
    await insertCard(deckB, 'b1', '別deck1');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result.length, 3);
    expect(result.every((m) => m.startsWith('同deck')), isTrue);
  });

  test('同 deck 不足時,會回退到其他 deck 補滿', () async {
    final deckA = await insertDeck('A');
    final deckB = await insertDeck('B');
    final target = await insertCard(deckA, 'target', '目標');
    await insertCard(deckA, 'a1', '同deck1');
    await insertCard(deckB, 'b1', '別deck1');
    await insertCard(deckB, 'b2', '別deck2');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result.length, 3);
    expect(result, contains('同deck1'));
    expect(result, contains('別deck1'));
    expect(result, contains('別deck2'));
  });

  test('avoidWith 排除有效:A 標記了 B,B 不會出現在 A 的選項裡', () async {
    final deck = await insertDeck('A');
    final target = await insertCard(deck, 'target', '目標', avoidWith: ['b']);
    await insertCard(deck, 'b', '避開的');
    await insertCard(deck, 'c', '可以的1');
    await insertCard(deck, 'd', '可以的2');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result, isNot(contains('避開的')));
  });

  test('avoidWith 雙向有效:B 標記了 A,A 也不會出現在 B 的選項裡', () async {
    final deck = await insertDeck('A');
    final a = await insertCard(deck, 'a', '甲');
    await insertCard(deck, 'b', '乙', avoidWith: ['a']);
    await insertCard(deck, 'c', '丙');
    await insertCard(deck, 'd', '丁');

    final result = await repo.distractorMeaningsFor(a, count: 3);

    expect(result, isNot(contains('乙')));
  });

  test('不會回傳與正確答案相同的 meaning', () async {
    final deck = await insertDeck('A');
    final target = await insertCard(deck, 'target', '相同意思');
    await insertCard(deck, 'dup', '相同意思');
    await insertCard(deck, 'c', '不同1');
    await insertCard(deck, 'd', '不同2');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result, isNot(contains('相同意思')));
  });

  test('不會回傳重複的 meaning', () async {
    final deck = await insertDeck('A');
    final target = await insertCard(deck, 'target', '目標');
    await insertCard(deck, 'a1', '重複意思');
    await insertCard(deck, 'a2', '重複意思');
    await insertCard(deck, 'a3', '重複意思');
    await insertCard(deck, 'a4', '唯一意思');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result.toSet().length, result.length);
  });

  test('全庫只有 1 張卡時,回傳空陣列,不 crash', () async {
    final deck = await insertDeck('A');
    final target = await insertCard(deck, 'target', '目標');

    final result = await repo.distractorMeaningsFor(target, count: 3);

    expect(result, isEmpty);
  });
}
