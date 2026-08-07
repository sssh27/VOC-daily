import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/scheduler.dart';

/// 涵蓋「我會了」按鈕的評分邏輯(SPEC.md 6.4 v5):連續呼叫
/// `reviewCard(state, 5)` 三次後,repetitions == 3、interval == 16、
/// easiness 約 2.8。這裡直接測 scheduler.dart 既有的公開函式組合,
/// **不修改 scheduler.dart 本身**。
void main() {
  test('連續三次 reviewCard(_, 5) 後,repetitions=3, interval=16, easiness≈2.8', () {
    var state = ScheduleState.initial();
    for (var i = 0; i < 3; i++) {
      state = reviewCard(state, 5);
    }

    expect(state.repetitions, 3);
    expect(state.interval, 16);
    expect(state.easiness, closeTo(2.8, 0.001));
  });

  test('dueDate 是呼叫當下往後推 interval 天', () {
    final now = DateTime(2026, 1, 1);
    var state = ScheduleState.initial();
    for (var i = 0; i < 3; i++) {
      state = reviewCard(state, 5, now: now);
    }

    expect(state.dueDate, DateTime(2026, 1, 17)); // 2026-01-01 + 16 天
  });
}
