import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/scheduler.dart';

void main() {
  test('first correct review sets interval to 1 day', () {
    final state = ScheduleState.initial();
    final result = reviewCard(state, 4);
    expect(result.interval, 1);
    expect(result.repetitions, 1);
  });

  test('second correct review sets interval to 6 days', () {
    var state = ScheduleState.initial();
    state = reviewCard(state, 4);
    final result = reviewCard(state, 4);
    expect(result.interval, 6);
  });

  test('failing a review resets repetitions and interval to 1', () {
    final state = ScheduleState(
      easiness: 2.5,
      interval: 10,
      repetitions: 3,
      dueDate: DateTime.now(),
    );
    final result = reviewCard(state, 1);
    expect(result.repetitions, 0);
    expect(result.interval, 1);
  });

  test('easiness never drops below 1.3', () {
    var state = ScheduleState.initial();
    for (var i = 0; i < 10; i++) {
      state = reviewCard(state, 0);
    }
    expect(state.easiness, greaterThanOrEqualTo(1.3));
  });
}
