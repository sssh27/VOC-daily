import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/answer_grading.dart';

void main() {
  test('按「忘了」→ quality 0(即使 isCorrect 是 true 也一樣,忘了優先)', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: true,
      elapsed: const Duration(seconds: 1),
    );
    expect(quality, 0);
  });

  test('選錯 → quality 0', () {
    final quality = gradeAnswer(
      isCorrect: false,
      gaveUp: false,
      elapsed: const Duration(seconds: 2),
    );
    expect(quality, 0);
  });

  test('選對,2 秒 → quality 5', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: false,
      elapsed: const Duration(seconds: 2),
    );
    expect(quality, 5);
  });

  test('選對,5 秒 → quality 4', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: false,
      elapsed: const Duration(seconds: 5),
    );
    expect(quality, 4);
  });

  test('選對,12 秒 → quality 3', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: false,
      elapsed: const Duration(seconds: 12),
    );
    expect(quality, 3);
  });

  test('邊界值:恰好 3 秒算在「3 秒內」→ quality 5', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: false,
      elapsed: const Duration(seconds: 3),
    );
    expect(quality, 5);
  });

  test('邊界值:恰好 8 秒算在「3-8 秒」→ quality 4', () {
    final quality = gradeAnswer(
      isCorrect: true,
      gaveUp: false,
      elapsed: const Duration(seconds: 8),
    );
    expect(quality, 4);
  });
}
