import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/data/card_repository.dart';
import 'package:vocab_srs_app/data/database.dart';

/// 涵蓋 CardRepository 的累計字數(SPEC.md 12.2)與 AppSettings 讀寫
/// (SPEC.md 12.3)。
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

  group('累計字數', () {
    test('等於 isIntroduced == true 的筆數,與牌組數量無關', () async {
      final deckA = await insertDeck('A');
      final deckB = await insertDeck('B');

      await insertCard(deckA, 'a1', isIntroduced: true);
      await insertCard(deckA, 'a2', isIntroduced: true);
      await insertCard(deckA, 'a3'); // 還在倉庫,不計入
      await insertCard(deckB, 'b1', isIntroduced: true);
      await insertCard(deckB, 'b2'); // 還在倉庫,不計入

      expect(await repo.introducedCount(), 3);
    });

    test('沒有任何卡片時回傳 0,不 crash', () async {
      expect(await repo.introducedCount(), 0);
    });
  });

  group('AppSettings', () {
    test('key 不存在時,getSetting 回傳 null,不 crash', () async {
      expect(await repo.getSetting('does_not_exist'), isNull);
    });

    test('setSetting 後可以讀回同樣的值', () async {
      await repo.setSetting('foo', 'bar');
      expect(await repo.getSetting('foo'), 'bar');
    });

    test('setSetting 對同一個 key 呼叫兩次會覆蓋,不是新增一筆', () async {
      await repo.setSetting('foo', 'bar');
      await repo.setSetting('foo', 'baz');
      expect(await repo.getSetting('foo'), 'baz');
    });

    test('celebratedMilestone 預設是 0(key 不存在時)', () async {
      expect(await repo.celebratedMilestone(), 0);
    });

    test('setCelebratedMilestone 後 celebratedMilestone 讀回同樣的值', () async {
      await repo.setCelebratedMilestone(100);
      expect(await repo.celebratedMilestone(), 100);
    });

    test('setCelebratedMilestone 可以覆蓋成更高的門檻', () async {
      await repo.setCelebratedMilestone(25);
      await repo.setCelebratedMilestone(100);
      expect(await repo.celebratedMilestone(), 100);
    });
  });
}
