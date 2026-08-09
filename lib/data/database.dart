import 'package:drift/drift.dart';

// Platform-specific connection setup. `dart.library.html` is only true on
// web builds (kIsWeb), so this resolves to connection_web.dart there and
// connection_native.dart everywhere else (Android/iOS/desktop). See
// SPEC.md 2.1 — Drift can't use NativeDatabase on web, it needs the WASM
// build instead.
import 'database_connection/connection_native.dart'
    if (dart.library.html) 'database_connection/connection_web.dart' as impl;

part 'database.g.dart';

class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get topic => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId => integer().references(Decks, #id)();

  TextColumn get word => text()();
  TextColumn get phonetic => text().withDefault(const Constant(''))();
  TextColumn get meaning => text()();
  TextColumn get example => text().withDefault(const Constant(''))();
  TextColumn get exampleZh => text().withDefault(const Constant(''))();

  // --- SM-2 scheduling fields ---
  RealColumn get easiness => real().withDefault(const Constant(2.5))();
  IntColumn get interval => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewed => dateTime().nullable()();

  /// 是否已被拉霸放進學習循環。false = 在倉庫裡,還沒開始學。
  BoolColumn get isIntroduced => boolean().withDefault(const Constant(false))();

  /// 【v3】四選一測驗時不可與哪些 word 同時出現在選項裡(避免語意過近造成
  /// 不公平的假陰性,見 SPEC.md 6.4「干擾項選取規則」)。JSON 編碼的字串
  /// 陣列,例如 `["postpone"]`;沒有設定就是 null,代表不排除任何字。
  TextColumn get avoidWith => text().nullable()();

  /// 【v6】例句中要標粗體的實際字串。目標字在例句裡形態改變時才需要
  /// (例如 word=`hang out`,例句用過去式 `hung out`),見 SPEC.md 6.3。
  /// null 代表用預設比對規則(word 本身,或詞形變化推測)。
  TextColumn get exampleMatch => text().nullable()();
}

/// 每日拉霸紀錄。一天只能有一筆(rollDate 為當天零點時間戳)。
class DailyRolls extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get rollDate => dateTime().unique()();
  IntColumn get quota => integer()();
  BoolColumn get wasCapped => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Decks, Cards, DailyRolls])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(cards, cards.isIntroduced);
            await m.createTable(dailyRolls);
          }
          if (from < 3) {
            await m.addColumn(cards, cards.avoidWith);
          }
          if (from < 4) {
            await m.addColumn(cards, cards.exampleMatch);
          }
        },
      );

  /// Cards due for review as of [asOf] (usually DateTime.now()).
  Future<List<Card>> dueCards(DateTime asOf) {
    return (select(cards)..where((c) => c.dueDate.isSmallerOrEqualValue(asOf)))
        .get();
  }
}

QueryExecutor _openConnection() {
  return impl.openConnection();
}
