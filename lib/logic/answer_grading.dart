/// 依作答結果與反應時間,換算成 SM-2 的 quality 值(0/3/4/5)。
///
/// 純函式,不碰 UI/資料庫,方便單元測試(見 test/answer_grading_test.dart)。
/// 規格見 docs/SPEC.md 6.4「評分規則」:
///
/// | 使用者行為 | quality |
/// |---|---|
/// | 按「忘了」 | 0 |
/// | 選錯 | 0 |
/// | 選對,3 秒內 | 5 |
/// | 選對,3–8 秒 | 4 |
/// | 選對,超過 8 秒 | 3 |
///
/// 邊界值定義(SPEC 沒有明講,這裡明確定案):
/// - 恰好 3 秒 → 算在「3 秒內」→ quality 5
/// - 恰好 8 秒 → 算在「3–8 秒」→ quality 4
/// 也就是兩個級距都是「大於前一個門檻、小於等於這一級的上限」。
library answer_grading;

const _fastThreshold = Duration(seconds: 3);
const _mediumThreshold = Duration(seconds: 8);

int gradeAnswer({
  required bool isCorrect,
  required bool gaveUp,
  required Duration elapsed,
}) {
  if (gaveUp || !isCorrect) return 0;
  if (elapsed <= _fastThreshold) return 5;
  if (elapsed <= _mediumThreshold) return 4;
  return 3;
}
