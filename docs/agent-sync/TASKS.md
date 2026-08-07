# TASKS.md

> 老大(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。

---

## 上一輪 review 結果

v4 實作品質good:規格都照做了,拉霸就地轉、認識卡、單一流程、補考機制、
7 個 distractor 測試都補上,commit 也切得乾淨。Shawn 本機已跑過 `flutter test`,24 個全過。

以下是這輪要處理的事:**兩個 bug 修正 + 一個新功能。**

---

## A. Bug 修正

### A1. 首頁文案在轉盤前就誤導使用者

**現況:** 今天還沒轉盤、且沒有到期字時,`_studyQueueCount == 0`,
首頁顯示「開始」按鈕禁用 + 「今天沒有要學的了」。

**問題:** 使用者只要轉一下轉盤就會有新字。這行文案在轉盤前跳出來等於謊報。

**修法:** 「今天沒有要學的了」這行只有在 `rolledToday == true` 時才可能顯示。
還沒轉盤時不顯示這行(轉盤本身就是明確的行動指引,不需要額外文案)。

### A2. 補考可能洗掉失敗紀錄

**現況:** `_confirmInfo()` 沒有判斷目前是不是補考階段。

**問題路徑:** 卡片答錯 → 進補考佇列 → 補考時 `distractorMeaningsFor()` 回傳空陣列
→ `_mode = _Mode.info` → 使用者按「下一個」→ `_confirmInfo()` 以 quality 4 寫回資料庫
→ **剛才的失敗紀錄被洗掉**,該卡被排到很久以後。

這違反 SPEC 6.4「補考結果不寫回資料庫」。

**修法:** `_confirmInfo()` 開頭加判斷,`_phase == _Phase.retry` 時只前進不寫回資料庫。

**觸發機率極低**(需要整個牌組只剩一張卡),但這是規格明文禁止的行為,補一行判斷即可。

---

## B. 新功能:「我會了」按鈕 + 額度補位機制

`docs/SPEC.md` 的 5.5、6.3b、6.4 已更新為 **v5**,請重讀。

### B1. 認識卡加第二個按鈕

```
   [ 下一個 ]        [ 我會了 ]
```

**「我會了」的實作:連續呼叫 `reviewCard(state, 5)` 三次**,前一次的回傳當下一次的輸入:

```dart
var st = currentState;
for (var i = 0; i < 3; i++) {
  st = reviewCard(st, 5);
}
// 結果:repetitions = 3, easiness = 2.8, interval = 16, dueDate = 今天 + 16 天
```

**絕對不要新增 `isMastered` 之類的欄位,也不要直接寫死 dueDate。**
一律透過 `reviewCard()`,維持 SM-2 單一入口。這點很重要,不要自作聰明簡化。

### B2. 額度補位機制

拉霸骰出的額度代表「**今天要真正學會的新字數量**」,不是「今天會看到幾張新字卡」。

| 使用者行為 | 是否計入額度 | 後續動作 |
|---|---|---|
| 按「下一個」 | ✅ 計入 | 前進下一張 |
| 按「我會了」 | ❌ 不計入 | **立刻從倉庫再引入 1 張**,接在認識卡佇列最後面 |

**不設補位次數上限。** 天然停止條件已足夠:倉庫空了、額度滿了、使用者自己關掉。

**不要因為 `starter_deck.json` 只有 30 個字就加人工上限。** 那是佔位用的測試資料,
不該讓它的限制影響主程式設計。

### B3. 倉庫用盡的提示

若倉庫已無未引入卡片、無法補位,在該次流程的**結束畫面**加一行:

> 單字庫快用完了,去生成新的吧

不要用彈窗或任何阻斷式互動。

---

## C. 測試

新增測試涵蓋:

1. 「我會了」連呼叫三次 `reviewCard(_, 5)` 後,`interval == 16`、`repetitions == 3`、
   `easiness` 約 2.8(浮點數用 `closeTo`)
2. 額度計數:按「下一個」計入、按「我會了」不計入
3. 補位邏輯:按「我會了」時會從倉庫引入 1 張(用 in-memory DB 測 repository 層)
4. 倉庫空時補位不會 crash,回傳 null 或空

建議把額度計數與補位判斷的邏輯抽成可測試的純函式或 repository method,
不要全部塞在 `StudyScreen` 的 State 裡,否則沒辦法測。

`flutter test` 必須全綠,`test/scheduler_test.dart` 依然**禁止修改**。

---

## D. Commit

一個步驟一個 commit,建議切成:

1. `fix: only show empty-state text after the daily roll`
2. `fix: do not persist review result during retry phase`
3. `feat: add "already know it" button on intro card`
4. `feat: quota counts only newly learned words, replenish on skip`
5. `test: cover already-know grading and quota replenishment`

`git push` 若你的環境沒有認證,在 `PROGRESS.md` 註明,由 Shawn 本機執行。

---

## 完成後

更新 `PROGRESS.md` 後停下來等 review。不要自行往下做 PWA manifest 或 SPEC 第 10 節其他步驟。
