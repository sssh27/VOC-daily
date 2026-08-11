/// 里程碑判斷邏輯(SPEC.md 12.3,v7 新增)。
///
/// 純函式,不碰 DB/UI,方便單元測試(見 test/milestone_test.dart)。
library milestone;

/// 累計字數的慶祝門檻。跨越時完成畫面要改成特別版本,每個門檻只慶祝一次。
const milestoneThresholds = [25, 50, 100, 200, 350, 500, 750, 1000];

/// 依目前累計字數 [total] 與已慶祝過的最高門檻 [lastCelebrated],算出這次
/// 該不該慶祝、慶祝哪一個門檻。
///
/// 找出所有滿足 `lastCelebrated < threshold <= total` 的門檻,取其中最大者。
/// 一次跨過多個門檻時只回傳最高的那個,呼叫端應該把 `celebrated_milestone`
/// 更新成這個回傳值,而不是逐一慶祝。
///
/// 沒有新門檻可慶祝時回傳 `null`。
int? milestoneToCelebrate({required int total, required int lastCelebrated}) {
  int? result;
  for (final threshold in milestoneThresholds) {
    if (lastCelebrated < threshold && threshold <= total) {
      result = threshold;
    }
  }
  return result;
}
