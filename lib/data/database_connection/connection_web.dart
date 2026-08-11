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
    // 診斷用:如果資料庫沒有跨 session 持久化,先看瀏覽器 console 印出的
    // 這行——如果 chosenImplementation 是 inMemory,代表 OPFS/IndexedDB
    // 都不可用,退回純記憶體儲存,重整頁面就會全部清空。missingFeatures
    // 非空的話會列出瀏覽器缺少哪些能力(常見原因是 flutter run 的開發
    // 伺服器每次用不同的 port,IndexedDB/OPFS 是綁 origin 的,port 一變
    // 等於整個換了一個新的儲存空間——這不是資料庫本身壞掉,見
    // docs/agent-sync/PROGRESS.md 的說明)。
    // ignore: avoid_print
    print(
      'DB storage: ${result.chosenImplementation}, '
      'missing features: ${result.missingFeatures}',
    );
    return result.resolvedExecutor;
  }));
}
