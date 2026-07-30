import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}

@DriftDatabase(tables: [Decks, Cards])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Cards due for review as of [asOf] (usually DateTime.now()).
  Future<List<Card>> dueCards(DateTime asOf) {
    return (select(cards)..where((c) => c.dueDate.isSmallerOrEqualValue(asOf)))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vocab_srs.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
