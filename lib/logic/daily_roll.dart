/// 每日拉霸邏輯。依積壓量決定今日新字額度。
///
/// 純函式,不碰資料庫/UI,方便單元測試(見 test/daily_roll_test.dart)。
/// 規格見 SPEC.md 5.2 / 5.3 / 5.4。
library daily_roll;

import 'dart:math';

/// 拉霸結果
class RollResult {
  final int quota; // 0, 3, 4, 5, 6
  final bool wasCapped; // 是否因積壓被下修
  bool get isJackpot => quota == 0 && !wasCapped; // 真正的中獎(非被下修導致的 0)

  const RollResult({required this.quota, required this.wasCapped});
}

/// 正常狀態(積壓 0–20 張)的權重表。5.2 節。
const Map<int, int> _baseWeights = {
  0: 5,
  3: 30,
  4: 30,
  5: 25,
  6: 10,
};

/// 依積壓量骰出今日新字額度。
/// [backlogCount] 見 5.1 定義
/// [random] 可注入以便測試
RollResult rollNewCardQuota(int backlogCount, {Random? random}) {
  final rng = random ?? Random();

  final int cap;
  final bool wasCapped;
  if (backlogCount <= 20) {
    cap = 6;
    wasCapped = false;
  } else if (backlogCount <= 50) {
    cap = 4;
    wasCapped = true;
  } else {
    cap = 0;
    wasCapped = true;
  }

  if (cap == 0) {
    return const RollResult(quota: 0, wasCapped: true);
  }

  // 只保留 <= cap 的選項,並依原比例重新正規化。
  final allowed = <int, int>{
    for (final entry in _baseWeights.entries)
      if (entry.key <= cap) entry.key: entry.value,
  };
  final totalWeight = allowed.values.fold<int>(0, (a, b) => a + b);

  var roll = rng.nextInt(totalWeight);
  int quota = allowed.keys.first;
  for (final entry in allowed.entries) {
    if (roll < entry.value) {
      quota = entry.key;
      break;
    }
    roll -= entry.value;
  }

  return RollResult(quota: quota, wasCapped: wasCapped);
}
