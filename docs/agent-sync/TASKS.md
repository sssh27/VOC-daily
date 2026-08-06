# TASKS.md

> 老大(規格方)指派的工作順序。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。

---

## 上一輪 review 結果

v3 的實作品質不錯:規格有照做、`scheduler.dart` 沒被動、分級邏輯有抽成純函式方便測試。
以下是這一輪要處理的事,分成「Shawn 的版面調整」和「我 review 出來的缺口」。

---

## A. 版面重構(Shawn 指定)

核心原則:**整潔俐落。整個 App 只有兩個主要畫面。**

`docs/SPEC.md` 的 6.1 / 6.2 / 6.3b / 6.4 / 6.5 已更新為 **v4**,請重讀那幾節。

### A1. 刪除獨立拉霸畫面,改成首頁就地轉

- **刪除** `lib/screens/daily_roll_screen.dart`
- 拉霸動畫改在 `home_screen.dart` 就地播放
- 理由:首頁本來就有轉盤圖示,點下去卻跳到另一頁看第二個轉盤,是無意義的重複

### A2. 首頁極簡化

只保留三個元素:轉盤、`[開始]` 按鈕、右上角 ☰(通往單字庫)。

**移除**:「待複習:N 張」這行、「開始複習」按鈕、「我的牌組」按鈕。

### A3. 新字與到期字合併成單一流程

- `review_screen.dart` 的 class 改名 `ReviewScreen` → `StudyScreen`(檔名不動,避免大量 import 改動)
- 畫面標題「複習」→「學習」
- 佇列 = 新字(前)+ 到期字(後),見 SPEC 6.4
- **全 App 任何地方都不得出現「複習」兩個字**(Shawn 說那讓他感覺像在上課)

### A4. 新字改用「認識卡」,不考

- **新增** `lib/widgets/intro_card.dart`(見 SPEC 6.3b)
- 新字第一次出現只給看,底部一個「下一個」按鈕
- 按下時呼叫 `reviewCard(state, 4)`,結果是 interval=1、easiness 維持 2.5、明天開始考
- 理由:第一次見到的字直接考四選一,使用者只能亂猜,產生的是雜訊而非有效訊號

### A5. 牌組列表降級為「單字庫」

- 從主流程移除,改由首頁右上角 ☰ 進入
- 標題「我的牌組」→「單字庫」
- **資料層的 Deck 概念保留**,不要拿掉。它有兩個實際用途:
  1. AI 一次生成一批,需要容器才能後續管理/刪除
  2. 四選一的干擾項優先從同 deck 挑,語意接近才有鑑別度

---

## B. 答錯補考機制(新增)

見 SPEC 6.4「答錯補考機制」。重點:

1. 答錯或按「忘了」的卡,排到本次流程**最後補考一次**
2. 每張卡一次流程**最多補考一次**,補考再錯不再排入
3. **補考結果不寫回資料庫** —— 排程已在第一次作答時決定,不能讓使用者靠補考洗掉失敗紀錄
4. 補考題外觀與一般題目完全相同,不要標示「這是補考」

---

## C. 我 review 出來的缺口(必修)

### C1. `distractorMeaningsFor()` 零測試覆蓋 —— 最優先

這是目前最複雜的新邏輯(同 deck 優先 + `avoidWith` 雙向排除 + 回退全庫),
卻一個測試都沒有。這種選取邏輯出錯很難察覺,使用者只會覺得「選項怪怪的」。

用 `AppDatabase.forTesting()` 搭配 in-memory database 寫測試,至少涵蓋:

1. 同 deck 有足夠卡片時,3 個 distractor 全部來自同 deck
2. 同 deck 不足時,會回退到其他 deck 補滿
3. `avoidWith` 排除有效:A 標記了 B,B 不會出現在 A 的選項裡
4. `avoidWith` **雙向**有效:B 標記了 A,A 也不會出現在 B 的選項裡
5. 不會回傳與正確答案相同的 meaning
6. 不會回傳重複的 meaning
7. 全庫只有 1 張卡時,回傳空陣列(不 crash)

### C2. 選項不足 3 個時沒處理

見 SPEC 6.4「選項不足時的處理」:

| distractor 數 | 行為 |
|---|---|
| 3 | 正常四選一 |
| 1–2 | 顯示 2–3 個選項,照常計分 |
| 0 | 改用認識卡顯示,按「下一個」以 quality 4 計 |

### C3. 答錯的停留時間拉長

目前答對/答錯都停 1.4 秒。答錯時要看清楚正確答案 + 中譯,1.4 秒不夠。

- 答對 → 1.4 秒
- 答錯或按「忘了」 → **3 秒**

---

## D. 測試與驗證

`flutter test` 必須全綠。預期測試數:

- `scheduler_test.dart` 4 個(**禁止修改**)
- `daily_roll_test.dart` 6 個
- `answer_grading_test.dart` 7 個
- `distractor_test.dart` 7 個(C1 新增)

如果你的環境沒有 Flutter SDK 跑不了測試,在 `PROGRESS.md` 明確註明,由 Shawn 本機驗證。

---

## E. Commit

照「一個步驟一個 commit」做。建議切成:

1. `refactor: remove standalone roll screen, roll inline on home`
2. `feat: intro card for first exposure to new words`
3. `refactor: merge new and due cards into single study flow`
4. `feat: retry queue for failed cards within session`
5. `test: cover distractor selection logic`
6. `fix: handle insufficient distractors, longer reveal on wrong answer`

`git push` 若你的環境沒有認證,在 `PROGRESS.md` 註明,由 Shawn 本機執行。

---

## 完成後

更新 `PROGRESS.md` 後停下來等 review。不要自行往下做 PWA manifest 或 SPEC 第 10 節其他步驟。
