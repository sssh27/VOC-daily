// Native (Android/iOS/desktop) database connection.
// Not used on web builds — see connection_web.dart for the WASM version.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vocab_srs.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
