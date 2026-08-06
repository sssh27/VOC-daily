import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/daily_roll.dart';

void main() {
  test('積壓 0 張時,骰 10000 次,結果集合只包含 {0, 3, 4, 5, 6}', () {
    final rng = Random(1);
    final seen = <int>{};
    for (var i = 0; i < 10000; i++) {
      final result = rollNewCardQuota(0, random: rng);
      seen.add(result.quota);
    }
    expect(seen, {0, 3, 4, 5, 6});
  });

  test('積壓 0 張時,骰 10000 次,平均值落在 3.7 ~ 4.2 之間', () {
    final rng = Random(2);
    var sum = 0;
    const n = 10000;
    for (var i = 0; i < n; i++) {
      sum += rollNewCardQuota(0, random: rng).quota;
    }
    final avg = sum / n;
    expect(avg, greaterThanOrEqualTo(3.7));
    expect(avg, lessThanOrEqualTo(4.2));
  });

  test('積壓 30 張時,骰 1000 次,結果不曾超過 4,且 wasCapped == true', () {
    final rng = Random(3);
    for (var i = 0; i < 1000; i++) {
      final result = rollNewCardQuota(30, random: rng);
      expect(result.quota, lessThanOrEqualTo(4));
      expect(result.wasCapped, isTrue);
    }
  });

  test('積壓 60 張時,骰 100 次,結果永遠是 0,且 wasCapped == true', () {
    final rng = Random(4);
    for (var i = 0; i < 100; i++) {
      final result = rollNewCardQuota(60, random: rng);
      expect(result.quota, 0);
      expect(result.wasCapped, isTrue);
    }
  });

  test('積壓 60 張骰出的 0,isJackpot 必須是 false', () {
    final result = rollNewCardQuota(60, random: Random(5));
    expect(result.quota, 0);
    expect(result.isJackpot, isFalse);
  });

  test('積壓 0 張骰出的 0,isJackpot 必須是 true', () {
    // 用固定 seed 找一個會骰出 0 的情況,或直接構造 RollResult 驗證邏輯。
    RollResult? jackpotResult;
    final rng = Random(6);
    for (var i = 0; i < 10000; i++) {
      final result = rollNewCardQuota(0, random: rng);
      if (result.quota == 0) {
        jackpotResult = result;
        break;
      }
    }
    expect(jackpotResult, isNotNull);
    expect(jackpotResult!.isJackpot, isTrue);
  });
}
