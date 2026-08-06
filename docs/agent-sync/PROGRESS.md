# PROGRESS.md

> 寫這份文件的人:老二(實作方)
> 目的:對照 `docs/SPEC.md`,誠實記錄目前專案的真實狀態。
> 舊版完整報告在 `docs/agent-sync/archive/IMPLEMENTATION_REPORT.md`。

---

## ⚠️ 流程瑕疵先說清楚

上一輪(v3,複習畫面改成四選一+忘了按鈕+反應時間分級那輪)的 code 我做完了,
但**忘了在那輪結束時 commit**——只在那輪開頭照 TASKS.md 第 0 項的指示 commit
了「上上一輪(v2)」的成果(commit `3fe7bed`),之後 v3 的變動(刪 `flashcard.dart`、
新增 `question_card.dart`、`avoidWith` 支援等)就一直停在工作目錄沒進 git。

這一輪(v4)開始時發現這個狀況,已經把 v3 + v4 的變動一起補進 git 了(見下方
commit 清單)。以後我會每完成 TASKS.md 一個小節就 commit 一次,不會再累積。

---

## 這一輪(v4)做了什麼

依 `docs/agent-sync/TASKS.md` 指派完成 A、B、C、D、E 五個部分。

### A. 版面重構

- **A1** `lib/screens/daily_roll_screen.dart` 已刪除。拉霸動畫改在
  `home_screen.dart` 就地播放(`Timer.periodic` 在首頁的圓形按鈕內跳動數字,
  動畫結束自動呼叫 `recordRoll()` + `introduceNewCards()`,不用再多按一次
  「開始學習」)。
- **A2** 首頁極簡化為轉盤 + 「開始」按鈕 + 右上角 ☰。「待複習:N 張」、
  「開始複習」、「我的牌組」按鈕都拿掉了。
- **A3** `review_screen.dart` 的 class 從 `ReviewScreen` 改名 `StudyScreen`
  (檔名維持不動),AppBar 標題「複習」→「學習」。佇列改成
  `card_repository.dart` 的新方法 `studyQueue()`:新字(`lastReviewed==null`,
  依 id 排序)在前,到期字(`lastReviewed!=null` 且到期,依 dueDate 排序)在後。
- **A4** 新增 `lib/widgets/intro_card.dart`,新字第一次出現用這個顯示,只有
  「下一個」按鈕,按下去固定 `reviewCard(state, 4)` 並寫回資料庫。
- **A5** `decks_screen.dart` 標題改「單字庫」,從首頁 ☰ 進入,不在主流程。
  Deck 概念在資料層完全保留(AI 生成批次管理 + distractor 同 deck 優先都要用到)。

### B. 答錯補考機制

`review_screen.dart`(`StudyScreen`)內用 `_retryQueue` / `_alreadyRetried`
實作:

- 主佇列中答錯或按「忘了」的到期字卡片,加進 `_retryQueue`,並用
  `_alreadyRetried`(`Set<int>`)標記,同一張卡最多補考一次
- 主佇列跑完後,若 `_retryQueue` 非空,自動接上去繼續
- 補考階段(`_phase == _Phase.retry`)的作答結果**不呼叫 `submitReview()`**,
  只更新畫面顯示(標色 + 顯示中譯),不碰資料庫,SM-2 排程維持第一次作答時
  就決定好的結果
- 補考題外觀跟一般題目完全相同,沒有加任何「這是補考」的標示
- 新字用的認識卡不會產生補考(沒有答錯的可能,`_confirmInfo()` 固定寫回)

### C. Review 出來的缺口

- **C1** 新增 `test/distractor_test.dart`,用 `AppDatabase.forTesting()` +
  `NativeDatabase.memory()` 搭配一個真的 in-memory 資料庫測
  `distractorMeaningsFor()`,涵蓋你列的全部 7 種情況(同 deck 足夠/不足時回退、
  avoidWith 單向與雙向排除、不重複正確答案、不重複彼此、只有 1 張卡不崩潰)。
- **C2** `_prepareCurrent()` 依 `distractorMeaningsFor()` 回傳數量分三種行為:
  3 個→正常四選一;1–2 個→照樣出題,選項數就是實際拿到的數量(沒有特別
  補到 4 個);0 個→整張卡改用 `IntroCard` 顯示,按「下一個」固定
  `reviewCard(state, 4)` 並寫回(這不是補考,是這張到期字唯一的一次結果)。
- **C3** 停留時間:答對 1.4 秒,答錯或按「忘了」改成 3 秒
  (`_correctRevealDuration` / `_wrongRevealDuration`)。

### D. 測試

我這邊 sandbox 沒有 Flutter SDK,無法自己跑 `flutter test`。預期測試數:

| 檔案 | 案例數 | 狀態 |
|---|---|---|
| `test/scheduler_test.dart` | 4 | **完全沒動**,一如既往 |
| `test/daily_roll_test.dart` | 6 | 沒動這輪邏輯 |
| `test/answer_grading_test.dart` | 7 | 沒動這輪邏輯 |
| `test/distractor_test.dart` | 7 | **這輪新增** |

合計 24 個。麻煩你本機跑:

```
dart run build_runner build --delete-conflicting-outputs
flutter test
```

`database.dart` 這次沒有加新欄位(`avoidWith` 是上一輪加的,已經在 g.dart 裡),
理論上不用重跑 build_runner 也能過,但保險起見還是建議跑一次。

### E. Commit

這輪 + 補齊 v3 遺漏的變動,總共切了 6 個 commit:

1. `docs: add CLAUDE.md, sync SPEC.md and TASKS.md from 老大`
2. `refactor: remove standalone roll screen, roll inline on home`
3. `feat: intro card, shared word-highlight helper, avoidWith distractor support`
4. `refactor: merge new/due queue into study screen with retry logic and reaction-time grading`
5. `refactor: rename decks screen to 單字庫; fix starter_deck.json postpone/procrastinate wording`
6. `test: cover distractor selection logic`

（這份 PROGRESS.md 更新完會是第 7 個 commit。）

**`git push` 我這邊還是跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。目前本地 `main` 領先 `origin/main` 8 個 commit。

---

## 額外的實作決定(沒在 TASKS.md 明講)

`_prepareCurrent()` 對「1–2 個 distractor」的處理是直接照拿到的數量出題
(2 或 3 個選項),沒有嘗試從別處硬湊到 4 個——因為 SPEC 6.4 的表格寫的是
「顯示 2–3 個選項」,不是「湊到 4 個」,所以我照字面實作。如果你的原意是
希望即使選項不足也盡量湊到 4 個(例如允許 distractor 重複使用正確答案以外
的字),麻煩告訴我,這裡改起來不難。

---

## 累計完成項目(對照 SPEC.md 全部章節,v4)

| SPEC 章節 | 項目 | 狀態 |
|---|---|---|
| 6.1 | 首頁極簡化 + 就地拉霸 | ✅ 完成 |
| 6.2 | 獨立拉霸畫面 | ✅ 已刪除 |
| 6.3 | `question_card.dart` | ✅ 完成(這輪抽出共用的 `word_highlight.dart`) |
| 6.3b | `intro_card.dart` | ✅ 完成(新增) |
| 6.4 | 學習畫面(合併佇列 + 認識卡 + 四選一 + 補考佇列 + 選項不足處理) | ✅ 完成 |
| 6.5 | 單字庫(降級為次要畫面) | ✅ 完成 |
| 6.6 | AI 生成畫面 | ✅ 邏輯完成,未接真實 API key |
| 7 | 內建牌組 | ✅ 完成,內容已 review 過 |
| 9.1 | 單元測試 | ✅ 應為 24 個,需你本機跑 `flutter test` 驗證 |

---

## 尚未完成

1. AI 生成功能沒有真實 API key 可測試
2. SPEC 第 10 節第 10 步(PWA manifest)依指示不動
3. `git push`,需要你本機執行
4. 這輪的 code 我這邊沒有 Flutter/Dart 環境跑 `flutter test` 驗證,需要你本機確認全綠

---

## 技術債(照舊,尚未處理)

> **Web WASM 檔案來源非官方管道**
> `web/sqlite3.wasm` 目前取自本機 pub cache 的 drift devtools build,
> 非官方指定來源。實測功能正常,但 PWA 上線前必須換成官方 release 檔案並回歸測試。
> 官方來源:
> - `sqlite3.wasm` → https://github.com/simolus3/sqlite3.dart/releases
> - `drift_worker.dart.js` → https://github.com/simolus3/drift/releases
>
> 兩者需取同一 drift release 對應版本,混版會有難查的問題。現在不用處理。

---

## 下一步建議

等你本機跑完 `flutter test` 全綠、`git push` 完成,再麻煩老大 review 這輪的
`home_screen.dart` / `review_screen.dart`(`StudyScreen`)/ `card_repository.dart`
的 `studyQueue()` 與 `distractorMeaningsFor()`。停在這裡,不往下做 PWA manifest。
