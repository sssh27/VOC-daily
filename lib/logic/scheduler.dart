/// SM-2 spaced repetition algorithm.
///
/// This is the core of the app: given a card's current scheduling state
/// and how well the user recalled it (quality 0-5), it returns the new
/// state, including the next date the card should reappear.
///
/// This file has zero dependency on the database or UI, so it's easy
/// to unit test in isolation (see test/scheduler_test.dart).
library scheduler;

class ScheduleState {
  final double easiness;
  final int interval; // days until next review
  final int repetitions; // consecutive successful reviews
  final DateTime dueDate;

  const ScheduleState({
    required this.easiness,
    required this.interval,
    required this.repetitions,
    required this.dueDate,
  });

  factory ScheduleState.initial() => ScheduleState(
        easiness: 2.5,
        interval: 0,
        repetitions: 0,
        dueDate: DateTime.now(),
      );
}

/// quality meaning:
///   0-2 = forgot / couldn't recall -> restart the interval
///   3   = recalled, but it was hard
///   4   = recalled normally
///   5   = recalled easily
ScheduleState reviewCard(ScheduleState state, int quality, {DateTime? now}) {
  assert(quality >= 0 && quality <= 5);
  final today = now ?? DateTime.now();

  int repetitions = state.repetitions;
  int interval = state.interval;
  double easiness = state.easiness;

  if (quality < 3) {
    repetitions = 0;
    interval = 1;
  } else {
    if (repetitions == 0) {
      interval = 1;
    } else if (repetitions == 1) {
      interval = 6;
    } else {
      interval = (interval * easiness).round();
    }
    repetitions += 1;
  }

  easiness += 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
  if (easiness < 1.3) easiness = 1.3;

  return ScheduleState(
    easiness: easiness,
    interval: interval,
    repetitions: repetitions,
    dueDate: today.add(Duration(days: interval)),
  );
}
