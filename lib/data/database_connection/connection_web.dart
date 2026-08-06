// Web (WASM) database connection.
//
// Requires `sqlite3.wasm` and `drift_worker.dart.js` to be present under
// web/ (see SPEC.md 2.1 and README for how to generate them locally — this
// repo doesn't have a Dart/Flutter toolchain available to build them here).
// If they are missing, opening the database will throw at runtime; the app
// itself still builds and runs fine on non-web platforms without these
// files.
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'vocab_srs',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  }));
}
