import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/card_repository.dart';
import 'data/database.dart';

/// 全 App 共用的單一資料庫連線。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(appDatabaseProvider));
});
