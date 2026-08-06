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
  int get schemaVersion => 2;

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
