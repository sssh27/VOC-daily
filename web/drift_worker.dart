// Entry point for drift's web worker. This file is compiled to JavaScript
// locally (dart2js) — see README / SPEC.md 2.1 for the command. It is not
// run directly by `flutter run`; drift loads the compiled
// `drift_worker.dart.js` output from web/ at runtime.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
