import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/milestone.dart';

/// 涵蓋 milestoneToCelebrate() 的里程碑判斷邏輯(SPEC.md 12.3,v7)。
void main() {
  test('累計 24,尚未達到 25 門檻 → 不觸發', () {
    final result = milestoneToCelebrate(total: 24, lastCelebrated: 0);
    expect(result, isNull);
  });

  test('累計 25 → 觸發,回傳 25', () {
    final result = milestoneToCelebrate(total: 25, lastCelebrated: 0);
    expect(result, 25);
  });

  test('celebrated_milestone 已是 25,累計仍為 25 → 不再觸發', () {
    final result = milestoneToCelebrate(total: 25, lastCelebrated: 25);
    expect(result, isNull);
  });

  test('celebrated_milestone=25,累計跳到 120 → 只回傳最高的 100', () {
    final result = milestoneToCelebrate(total: 120, lastCelebrated: 25);
    expect(result, 100);
  });

  test('一次跨過所有門檻(從 0 到 1200)→ 只回傳最高的 1000', () {
    final result = milestoneToCelebrate(total: 1200, lastCelebrated: 0);
    expect(result, 1000);
  });

  test('累計剛好等於下一個門檻(50)→ 觸發 50', () {
    final result = milestoneToCelebrate(total: 50, lastCelebrated: 25);
    expect(result, 50);
  });

  test('累計介於兩個門檻之間(60,lastCelebrated=50)→ 不觸發', () {
    final result = milestoneToCelebrate(total: 60, lastCelebrated: 50);
    expect(result, isNull);
  });

  test('累計超過所有門檻且都已慶祝過(lastCelebrated=1000)→ 不再觸發', () {
    final result = milestoneToCelebrate(total: 5000, lastCelebrated: 1000);
    expect(result, isNull);
  });
}
