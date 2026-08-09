# PROGRESS.md

> 寫這份文件的人:聖多諾黑(實作方)
> 目的:對照 `docs/SPEC.md`,誠實記錄目前專案的真實狀態。
> 舊版完整報告在 `docs/agent-sync/archive/IMPLEMENTATION_REPORT.md`。

---

## 這一輪(v6)做了什麼

依 `docs/agent-sync/TASKS.md` 的 A(多牌組載入)、B(測試)、F(`exampleMatch`
欄位)完成,細節如下。時間敏感這輪(Shawn 要搭郵輪),優先把內容導入做完。

### A. 多牌組載入機制

- `lib/services/starter_deck_loader.dart` 已刪除,改名為
  `lib/services/deck_loader.dart`,class `StarterDeckLoader` → `DeckLoader`。
- 內建牌組清單 `_deckAssets`:`starter_deck.json` + `cruise_travel.json`。
  之後新增字庫只要放 json + 註冊 `pubspec.yaml` + 加進這個清單。
- `importIfEmpty()` → `importMissingDecks()`:不再靠「整庫是否為空」判斷,
  改成逐一依 `Deck.name` 查詢是否已存在(新增
  `CardRepository.deckExistsByName()`),不存在才匯入。已存在的牌組**不覆蓋、
  不更新**,不會動到 Shawn 現有的學習進度。
- 單一牌組匯入包在 `try/catch` 裡,失敗只印錯誤訊息、繼續處理下一個,不會讓
  `_AppBootstrap` 卡死。
- `DeckLoader` 建構子加了選填的 `assetPaths` 參數(預設用內建清單),單純是
  為了讓測試能注入一個包含不存在路徑的清單,驗證失敗容錯——正式程式碼路徑
  不會用到這個參數。
- `main.dart`、`pubspec.yaml`(assets 加 `cruise_travel.json`)、
  `generate_screen.dart`(`createDeckWithCards()` 的呼叫多帶一個
  `exampleMatch: null`)都同步更新。

### F. `exampleMatch` 欄位

- **F1** `database.dart` 的 `Cards` 表加 `exampleMatch`(nullable text),
  `schemaVersion` 3 → 4,`onUpgrade` 加 `from < 4` 分支補這個欄位。**這步驟
  改完需要 Shawn 本機跑一次 `dart run build_runner build
  --delete-conflicting-outputs` 重新產生 `database.g.dart`,否則編譯會失敗**
  (sandbox 沒有 Dart SDK,我沒辦法自己跑)。
- **F2** `word_highlight.dart` 的 `highlightWordSpans()` 加 `exampleMatch`
  選填參數,比對邏輯照 SPEC 6.3 改成四步驟:有 `exampleMatch` 就精確
  (大小寫敏感)比對且**不落回**其他規則,找不到就整句原樣顯示;沒有
  `exampleMatch` 才走原本的 word 比對 + 詞形變化推測。刻意沒有實作任何
  不規則動詞表。
- **F3** `QuestionCard` / `IntroCard` 都加了 `exampleMatch`(選填)欄位並轉呼叫
  `highlightWordSpans()`;`review_screen.dart` 三個用到這兩個元件的地方都補上
  `exampleMatch: card.exampleMatch`。`deck_loader.dart` 解析 JSON 的
  `exampleMatch` 欄位、`createDeckWithCards()` 的卡片參數型別多了
  `String? exampleMatch`(AI 生成路徑傳 `null`)。

### B / F4. 測試

sandbox 依然沒有 Flutter SDK,新增 2 個檔案:

| 檔案 | 案例數 | 涵蓋什麼 |
|---|---|---|
| `test/multi_deck_loader_test.dart` | 6 | `deckExistsByName()` 存在/不存在、空庫匯入兩個牌組、已有一個牌組時只匯入另一個且原牌組進度(`lastReviewed`)不變、兩個都存在不重複匯入、asset 路徑不存在不 crash |
| `test/example_match_test.dart` | 6 | `exampleMatch` 優先比對、找不到時整句原樣(不落回 word 比對)、沒有 `exampleMatch` 時 word 比對與詞形推測不變(回歸測試)、片語過去式範例、空字串視同沒有 |

新增 12 個,加上 v5 累計的 38 個,合計預期 50 個。麻煩本機跑:

```
dart run build_runner build --delete-conflicting-outputs
flutter test
```

`test/scheduler_test.dart` 完全沒動。

### 需要 Shawn 本機驗證的項目(TASKS.md C 節)

1. `flutter run -d chrome` 啟動後,單字庫頁面應看到**兩個**牌組
2. 「郵輪與旅遊實用」卡片數為 **166**
3. 「入門常用字」的已學進度沒有被重置
4. 轉盤 → 開始,新字會從兩個牌組混合出現

### D. Commit

這輪切了 5 個 commit:

1. `docs: sync SPEC.md and TASKS.md to v6`
2. `feat: multi-deck loader imports by name, adds cruise_travel deck`
3. `feat: exampleMatch-aware bold highlighting in example sentences`
4. `test: cover multi-deck import behaviour and exampleMatch highlighting`

（這份 PROGRESS.md 更新完會是第 5 個。）

跟 TASKS.md 建議的切法不太一樣,原因是 `deck_loader.dart` 這個新檔案裡
「改名+多牌組邏輯」跟「解析 exampleMatch 欄位」是同一個檔案裡的兩行改動,
硬切開會產生編譯不過的中間 commit,所以 commit 2 把 A(多牌組載入,含
`database.dart` 加欄位、`card_repository.dart` 的 `deckExistsByName()`
與 `createDeckWithCards()` 簽章)跟 F1/F3 合併處理;commit 3 只放 UI 層
真正「用 exampleMatch 來標粗體」的部分(`word_highlight.dart` /
`question_card.dart` / `intro_card.dart` / `review_screen.dart`)。

沒有把 `cruise_travel.json` 的新增獨立切一個 commit——它跟著 asset 註冊
(`pubspec.yaml`)一起在 commit 2 裡,因為沒有它 loader 的改動測試不完整,
分開意義不大。

**`git push` 一樣跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。

### 沒做的事

- `docs/SPEC.md` 第 10 節第 10 步(PWA manifest)沒有動,依指示停在這裡等 review。
- `assets/decks/cruise_travel.json` 內容完全沒有動過。

---

## 這一輪(v5)做了什麼

依 `docs/agent-sync/TASKS.md` 的 A(兩個 bug 修正)、B(「我會了」按鈕 + 額度補位)、
C(測試)、D(commit)完成,細節如下。

### A. Bug 修正

- **A1** `home_screen.dart`:「今天沒有要學的了」這行的顯示條件從
  `_studyQueueCount == 0` 改成 `rolledToday && _studyQueueCount == 0`,還沒轉盤前
  不會顯示這行文案。
- **A2** 補考不寫回資料庫:原本 `_confirmInfo()`(選項不足時的 fallback)沒有判斷
  補考階段。這輪重寫 `review_screen.dart` 時,把這個 fallback 統一改名
  `_confirmDueInfo()`,開頭就檢查 `if (_phase != _Phase.retry)` 才寫
  `submitReview()`,補考階段只前進、不動資料庫。

### B. 「我會了」按鈕 + 額度補位機制

- **B1** `IntroCard` 底下改成兩個按鈕並排:「下一個」/「我會了」
  (`_buildIntroMode()`)。「我會了」的實作照 TASKS.md 給的寫法,連續呼叫
  `reviewCard(state, 5)` 三次、把最終結果整包寫回 `submitReview()`,**沒有**新增
  `isMastered` 之類的欄位,也沒有直接寫死 `dueDate`——全部透過 `reviewCard()`
  單一入口跑出來。
- **B2** 額度計數與補位邏輯抽成 `lib/logic/intro_queue.dart` 的 `IntroQueue<T>`
  (純函式風格,泛型不依賴 Drift 的 `Card`,方便單元測試):
  - `confirmNext()`(對應「下一個」)→ `learnedCount++`,前進
  - `markAlreadyKnown()`(對應「我會了」)→ 不動 `learnedCount`,前進
  - `replenish(card)` → 把新卡接到佇列尾端,`card == null`(倉庫已空)時不做事
  補位的實際查詢/寫入是新增的 `CardRepository.replenishOneNewCard()`:從
  `isIntroduced == false` 的卡片中拿 1 張、設為已引入、`dueDate` 設今天,回傳它;
  倉庫空了回傳 `null`。**沒有設補位次數上限**,天然停止條件(倉庫空/使用者離開)
  已經足夠,也沒有因為 `starter_deck.json` 只有 30 個字而加任何人工上限。
- **B3** 完成畫面(`_Phase.done`)在 `_warehouseExhausted == true` 時多顯示一行
  「單字庫快用完了,去生成新的吧」,沒有彈窗。這個 flag 有兩個來源:一開始
  `newCards().length < todaysRoll.quota`(拉霸當下倉庫就不夠了),或任何一次
  `replenishOneNewCard()` 回傳 `null`。

### review_screen.dart 這輪的結構調整

原本新字跟到期字合併在同一條佇列裡(`_mainQueue`),這輪拆開了,因為新字現在
需要「我會了」的補位邏輯,到期字不需要:

- `_introQueue`:`IntroQueue<Card>`,裝 `repo.newCards()`
- `_dueQueue` / `_dueIndex`:到期字,邏輯跟 v4 一樣(四選一/選項不足 fallback)
- `_retryQueue` / `_retryIndex` / `_alreadyRetried`:補考佇列,跟 v4 一樣
- `_Phase` 從 `{main, retry, done}` 改成 `{intro, due, retry, done}`,`_settlePhase()`
  負責跳過空的階段

### C. 測試

sandbox 沒有 Flutter SDK,一樣無法自己跑 `flutter test`。這輪新增 3 個檔案:

| 檔案 | 案例數 | 涵蓋什麼 |
|---|---|---|
| `test/already_known_test.dart` | 2 | 連續三次 `reviewCard(_, 5)` 後 interval=16/repetitions=3/easiness≈2.8,以及 dueDate 換算 |
| `test/intro_queue_test.dart` | 8 | `IntroQueue` 的 confirmNext/markAlreadyKnown 計數、replenish、佇列跑完後的邊界行為 |
| `test/replenish_test.dart` | 4 | `CardRepository.replenishOneNewCard()`:成功補位、dueDate 正確、倉庫空回傳 null、連續補位直到用盡 |

新增 14 個,加上 v4 的 24 個,合計預期 38 個。麻煩本機跑:

```
dart run build_runner build --delete-conflicting-outputs
flutter test
```

`test/scheduler_test.dart` 完全沒動。

### D. Commit

這輪切了 6 個 commit(比 TASKS.md 建議的 5 個多一個,因為 `docs/SPEC.md` /
`docs/agent-sync/TASKS.md` 這兩份你已經更新到 v5 但還沒進 git,順手一起 commit 了):

1. `docs: update SPEC and TASKS to v5 (already-know button + quota replenishment)`
2. `fix: only show empty-state text after the daily roll`
3. `fix: do not persist review result during retry phase`
4. `feat: add already-know-it button on intro card with quota replenishment`
5. `test: cover already-know grading and quota replenishment`

（這份 PROGRESS.md 更新完會是第 6 個。）

**有一點要老實說**:A2 修正跟 B 的 IntroQueue 整合都動到同一個檔案
(`review_screen.dart`),我沒辦法把這個檔案的變動乾淨切成「只有 A2」跟
「只有 B」兩個 commit——目前是整個檔案的變動塞進 commit 3(`fix: do not persist
review result during retry phase`),commit 4 只包含新增的 `intro_queue.dart` 和
`card_repository.dart` 的改動。如果你想要更細的切法,我可以重新排。

**`git push` 一樣跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。

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

1. `docs: add CLAUDE.md, sync SPEC.md and TASKS.md from 國王餅`
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

等你本機跑完 `flutter test` 全綠、`git push` 完成,再麻煩國王餅 review 這輪的
`home_screen.dart` / `review_screen.dart`(`StudyScreen`)/ `card_repository.dart`
的 `studyQueue()` 與 `distractorMeaningsFor()`。停在這裡,不往下做 PWA manifest。
