# VOC-daily 實作報告

> 記錄日期:2026-08-04
> 對應規格書:`SPEC.md`
> 專案實際路徑:`C:\Users\shawn\VOC-daily`(原本在 OneDrive 底下,過程中搬出來,原因見下方「除錯過程」)

---

## 1. 今天做了什麼(總覽)

大致分成四個階段:

1. **資料夾健檢與清理** —— 找出 500 多個檔案的來源,清掉非原始碼的快取與模板垃圾
2. **依 SPEC.md 完整實作** —— 資料層、拉霸邏輯、六個畫面、AI 錯誤處理、內建牌組、Web 持久化
3. **部署除錯** —— OneDrive 導致建置失敗、資料夾路徑對不上、Drift/Flutter 命名衝突
4. **依你的回饋調整複習畫面 UX** —— 從「翻卡 + 忘記了/有點難/普通/簡單」改成「四選一測驗」,再把「例句挖空」改成「例句完整顯示 + 單字粗體」

---

## 2. 階段一:資料夾清理

原始資料夾裡 380+ 個檔案,主要是:

| 項目 | 內容 | 大小/數量 | 處理 |
|---|---|---|---|
| `.dart_tool/chrome-device/` | 之前 `flutter run -d chrome` 除錯留下的完整 Chrome 使用者設定檔快取(History、Cookies、LevelDB 等) | 176 個檔案,23MB | 刪除(會自動重建) |
| `build/` | 編譯輸出 | 51MB | 刪除(會自動重建) |
| `test/widget_test.dart` | `flutter create` 預設模板測試,引用不存在的 `MyApp` 類別 | 1 個檔案 | 刪除(會讓 `flutter test` 編譯失敗) |

清理後剩約 218 個檔案,都是真正的原始碼/專案設定。

---

## 3. 階段二:依 SPEC.md 的完整實作

### 3.1 資料層

**`lib/data/database.dart`**(修改)
- `Cards` 表新增 `isIntroduced`(bool,預設 false)欄位
- 新增 `DailyRolls` 表(`rollDate` unique、`quota`、`wasCapped`)
- `schemaVersion` 從 1 升到 2,加上 `MigrationStrategy`(`onCreate` 建全部表、`onUpgrade` 幫舊資料庫補欄位/建表,避免舊使用者資料庫升級後炸掉)
- 改用平台分流的 `_openConnection()`,實際邏輯移到下面兩個新檔案

**`lib/data/database_connection/connection_native.dart`**(新增)
原本 database.dart 裡的 `NativeDatabase.createInBackground(...)` 邏輯搬過來,給 Windows/Android/iOS/macOS/Linux 用。

**`lib/data/database_connection/connection_web.dart`**(新增)
Web 版用 `WasmDatabase.open(...)`,讀取 `web/sqlite3.wasm` 與 `web/drift_worker.dart.js`(見 3.5)。

**`lib/data/card_repository.dart`**(新增)
把所有 Drift 查詢封裝起來,畫面層不直接碰資料庫。主要方法:

| 方法 | 對應規格 | 說明 |
|---|---|---|
| `backlogCount()` | 5.1 | 積壓量(isIntroduced=true 且 dueDate < 今天零點) |
| `todaysRoll()` / `recordRoll()` | DailyRolls | 查詢/寫入今日拉霸紀錄,重複拉霸會丟 `StateError` |
| `introduceNewCards(quota)` | 5.5 | 引入新卡,回傳實際引入張數(倉庫不夠時 < quota) |
| `notIntroducedCount()` | 5.5 | 倉庫剩餘未引入張數 |
| `reviewQueue()` | 5.6 | 複習佇列(isIntroduced=true 且 dueDate <= 今天 23:59:59,依 dueDate 排序) |
| `submitReview(cardId, newState)` | 6.4 | 把 `reviewCard()` 算出的新 SM-2 狀態寫回 |
| `allDecks()` / `deckProgress(deckId)` | 6.5 | 牌組列表與已學/總數進度 |
| `createDeckWithCards(...)` | 6.6 / 7 | 建新牌組,卡片一律 `isIntroduced=false` |
| `allCards()` | (複習測驗用) | 全部卡片,當四選一測驗的干擾選項來源 |

### 3.2 拉霸邏輯

**`lib/logic/daily_roll.dart`**(新增)
純函式 `rollNewCardQuota(backlogCount, {random})`,依規格 5.2/5.3:

- 積壓 0–20 張:權重 {0:5%, 3:30%, 4:30%, 5:25%, 6:10%},期望值 3.95
- 積壓 21–50 張:只保留 ≤4 的選項並重新正規化,`wasCapped=true`
- 積壓 51+ 張:固定 0,`wasCapped=true`
- `RollResult.isJackpot` = `quota==0 && !wasCapped`(跟被下修的 0 區分開)

**`test/daily_roll_test.dart`**(新增)
6 個測試案例全數通過(規格 9.1 要求的全部涵蓋):積壓 0 張的機率分布與集合驗證、平均值範圍、積壓 30/60 張的上限行為、jackpot 判斷的兩種邊界。

### 3.3 內建牌組

**`assets/decks/starter_deck.json`**(新增)
30 個常用英文字,每張都有 word/phonetic/meaning/example/exampleZh 五個欄位齊全。**這份清單目前還沒經過你逐字確認**,規格書 9.3 有特別要求先給你看過。

**`lib/services/starter_deck_loader.dart`**(新增)
`importIfEmpty()`:App 啟動時檢查 Decks 表是不是空的,是的話才從 JSON 匯入,避免重複匯入。

**`pubspec.yaml`**(修改)
`assets` 區塊加上 `assets/decks/starter_deck.json`。

### 3.4 畫面

**`lib/widgets/flashcard.dart`**(重寫,但目前複習流程沒在用)
雙面翻卡元件 + `blankOutWord()` 挖空函式(大小寫不敏感、支援詞形變化比對)。因為複習畫面後來改成四選一測驗,這個元件目前是「規格書要求做但沒被複習畫面呼叫」的狀態,程式碼還在,乾淨可用。

**`lib/screens/review_screen.dart`**(重寫,而且改了兩次)
第一版依規格 6.4 做「翻卡 + 四個評分按鈕」;依你的要求改成**四選一測驗**:看英文單字 + 完整例句(單字本身粗體標示),四個中文意思選項(1 正確 + 3 個從全部卡片隨機抽的干擾項)。答對(quality=5)/答錯(quality=0)寫回 SM-2,答錯會顯示正確答案 1.4 秒後自動跳下一題。

**`lib/screens/daily_roll_screen.dart`**(新增)
轉盤動畫(Timer.periodic 快速跳數字,1.5 秒後定格)、依結果顯示對應文案(一般新字/JACKPOT/被下修安慰文案)、「開始學習」執行引入流程並導向複習畫面。

**`lib/screens/home_screen.dart`**(重寫)
依今天是否已拉霸切換畫面:沒拉霸只顯示拉霸按鈕(+ 有到期卡才顯示開始複習);已拉霸顯示今日新字/待複習張數/開始複習/我的牌組。**沒有**顯示積壓數字、連續天數、完成率(規格明確禁止)。

**`lib/screens/decks_screen.dart`**(新增)
牌組列表,每個牌組顯示「已學 X / Y 字」+ 進度條,底部「+ 新增牌組」導向生成畫面。

**`lib/screens/generate_screen.dart`**(修改)
補上數量選擇(10/20/30)、loading 狀態、預覽列表、重新生成/加入牌組按鈕,錯誤訊息對應 `AiServiceException` 的三種分類。

**`lib/services/ai_service.dart`**(修改)
新增 `AiServiceException`,把原本的通用 `Exception` 換成依規格分類的三種訊息:「尚未設定 API 金鑰」、「連線失敗,請檢查網路」、「AI 回傳格式異常,請再試一次」。**目前還沒有實際串上你的 AI 金鑰**,呼叫會停在「尚未設定 API 金鑰」這一步。

**`lib/providers.dart`**(新增)
Riverpod provider:`appDatabaseProvider`(全 App 共用一個資料庫連線)、`cardRepositoryProvider`。

**`lib/main.dart`**(修改)
App 啟動時先跑 `StarterDeckLoader.importIfEmpty()`(顯示 loading 轉圈),完成後才進首頁。

### 3.5 Web 持久化(WASM)

**`web/drift_worker.dart`**(新增,我寫的原始碼)→ 你在本機用 `dart compile js -O4` 編出 **`web/drift_worker.dart.js`**
**`web/sqlite3.wasm`** → 從你本機 pub cache 裡 `drift-2.34.3` 版附的檔案複製過來(跟 worker.js 同一個 drift 版本,理論上吻合)

這兩個檔案我這邊沒有 Dart/C 工具鏈能生成,是靠你本機環境完成的。

---

## 4. 階段三:部署除錯(過程記錄)

| 問題 | 原因 | 解法 |
|---|---|---|
| `build_runner` 報 `Unable to write file: ...\.dart_tool\build\...` | 專案放在 OneDrive 同步資料夾,即時同步跟 build_runner 大量寫檔互相鎖檔案 | 把整個專案搬到 `C:\Users\shawn\VOC-daily`(非 OneDrive 路徑,也是規格書原本建議的位置) |
| 搬完之後複習畫面還是舊的「忘記了/簡單」按鈕版本 | 我一直改的是舊的 OneDrive 路徑檔案,跟你電腦上真正在跑的新路徑不是同一份(兩份資料夾內容不同步) | 用 bash 把所有已完成的實作檔案從舊路徑複製到新路徑 `C:\Users\shawn\VOC-daily`,並刪除新路徑裡過期的 `database.g.dart` |
| `flutter run` 編譯失敗:`'Card' is imported from both 'flutter/material.dart' and 'vocab_srs_app/data/database.dart'` | Flutter 內建的 `Card` UI 元件跟 Drift 幫 `Cards` 資料表產生的 `Card` 資料類別撞名 | `review_screen.dart` 的 `import 'package:flutter/material.dart' hide Card;`(這個檔案沒用到 Flutter 的卡片元件,可以安全隱藏) |
| `sqlite3.wasm` 官方 release 頁面已經不附編譯好的檔案 | drift/sqlite3 套件維護方式改了 | 改從本機 pub cache 裡 `drift` 套件自帶的 devtools 版本複製(同版本號,應該吻合) |

---

## 5. 階段四:複習畫面 UX 調整(依你的回饋)

1. **原始規格版**:翻卡看正面(挖空例句)→ 點擊翻面看背面(完整例句+意思)→ 四個評分按鈕(忘記了/有點難/普通/簡單)
2. **改成四選一測驗**(你的要求):不翻卡了,直接看英文單字 + 例句 + 四個中文意思選項,答對/答錯直接算 SM-2 quality(5 分/0 分),自動跳下一題
3. **例句挖空邏輯調整**(你發現的問題):原本例句還是挖空(`It's more ______ to pay by card.`),但單字已經顯示在題目最上方,挖空沒有意義 → 改成**例句完整顯示,目標單字加粗**,其他字不變色不加粗

---

## 6. 重要檔案現況總表

| 檔案 | 狀態 | 現況 |
|---|---|---|
| `lib/logic/scheduler.dart` | **完全沒動** | SM-2 演算法,規格禁止改動,今天全程沒碰過邏輯 |
| `test/scheduler_test.dart` | **完全沒動** | 4 個測試,今天跑過確認全過 |
| `lib/logic/daily_roll.dart` | ✅ 完成 | 拉霸邏輯,6 個測試全過 |
| `lib/data/database.dart` | ✅ 完成 | schema v2,含 migration |
| `lib/data/card_repository.dart` | ✅ 完成 | 所有查詢封裝 |
| `lib/data/database_connection/*` | ✅ 完成 | native/web 平台分流 |
| `lib/services/starter_deck_loader.dart` | ✅ 完成 | 首次啟動匯入 |
| `assets/decks/starter_deck.json` | ⚠️ **待你確認** | 30 字內容規格要求先給你過目 |
| `lib/services/ai_service.dart` | ⚠️ **未串金鑰** | 錯誤處理邏輯完成,但沒有真的 API key 可測試生成流程 |
| `lib/screens/home_screen.dart` | ✅ 完成 | |
| `lib/screens/daily_roll_screen.dart` | ✅ 完成 | |
| `lib/screens/review_screen.dart` | ✅ 完成,已依你的回饋調整兩次 | 四選一測驗,例句單字粗體不挖空 |
| `lib/screens/decks_screen.dart` | ✅ 完成 | |
| `lib/screens/generate_screen.dart` | ✅ 完成(邏輯面) | 待金鑰才能實測 |
| `lib/widgets/flashcard.dart` | ✅ 已寫但**目前沒被呼叫** | 保留給以後如果想加回翻卡模式用 |
| `web/sqlite3.wasm` / `web/drift_worker.dart.js` | ✅ 已放置 | 來源見 3.5,建議之後找機會用官方管道驗證版本相容性 |
| `test/daily_roll_test.dart` | ✅ 完成 | 6/6 通過 |
| PWA manifest(圖示、名稱等) | ❌ 未處理 | 規格書列為「不在本次施工範圍」的第 10 步,尚未動 |

---

## 7. App 整體架構設計

### 7.1 分層

```
┌─────────────────────────────────────────┐
│  UI 層(lib/screens/*, lib/widgets/*)      │  ← Riverpod ConsumerWidget/ConsumerState
├─────────────────────────────────────────┤
│  狀態管理(lib/providers.dart)              │  ← appDatabaseProvider, cardRepositoryProvider
├─────────────────────────────────────────┤
│  邏輯層(lib/logic/*)                       │  ← scheduler.dart(SM-2)、daily_roll.dart(拉霸)
│                                            │     兩個都是純函式,不碰資料庫/UI,方便測試
├─────────────────────────────────────────┤
│  資料層(lib/data/*)                        │  ← card_repository.dart 封裝所有查詢
│                                            │     database.dart 定義 schema(Drift ORM)
├─────────────────────────────────────────┤
│  平台分流(lib/data/database_connection/*)  │  ← native(SQLite 檔案)/ web(WASM + IndexedDB)
└─────────────────────────────────────────┘
```

畫面永遠不直接 import `database.dart` 去下 SQL,一律透過 `card_repository.dart` 的方法;`review_screen.dart` 例外地需要 `Card`/`DailyRoll` 這些 Drift 生成的資料類別當型別標註,所以有 import,但沒有自己組查詢。

### 7.2 資料庫 schema(Drift/SQLite)

```
Decks
├── id (PK)
├── name
├── topic
└── createdAt

Cards
├── id (PK)
├── deckId (FK → Decks.id)
├── word / phonetic / meaning / example / exampleZh
├── easiness / interval / repetitions / dueDate / lastReviewed   ← SM-2 欄位
└── isIntroduced   ← 是否已被拉霸放進學習循環

DailyRolls
├── id (PK)
├── rollDate (unique,只存年月日)
├── quota
└── wasCapped
```

### 7.3 核心流程

**每日拉霸流程:**
```
使用者點拉霸按鈕
  → daily_roll_screen 讀 backlogCount()
  → rollNewCardQuota(backlog) 算出 quota + wasCapped
  → 1.5 秒動畫
  → recordRoll() 寫入 DailyRolls(防止同一天拉第二次)
  → 使用者按「開始學習」
  → introduceNewCards(quota):從 isIntroduced=false 的卡片挑最多 quota 張,設 isIntroduced=true、dueDate=今天
  → 導向複習畫面
```

**複習流程(四選一測驗):**
```
review_screen 讀 reviewQueue():isIntroduced=true 且 dueDate<=今天23:59:59,依 dueDate 排序
  → 每張卡:讀 allCards() 當干擾選項池,組出 1 正確 + 3 干擾的四選一
  → 使用者選答案
  → reviewCard(currentState, quality) 算出新的 SM-2 狀態(quality: 答對=5, 答錯=0)
  → submitReview() 寫回 easiness/interval/repetitions/dueDate/lastReviewed
  → 1.4 秒後自動下一題
  → 佇列清空 → 完成畫面
```

**AI 生成流程:**
```
generate_screen 輸入主題 + 選數量(10/20/30)
  → AiService.generateCards() 呼叫 OpenAI 相容 API(目前沒金鑰,會停在「尚未設定 API 金鑰」)
  → 預覽列表
  → 「加入牌組」→ createDeckWithCards():新 Deck + 卡片全部 isIntroduced=false(進倉庫,不會馬上開始學)
```

### 7.4 平台差異處理

- **原生平台**(Windows/macOS/Linux/Android/iOS):`NativeDatabase.createInBackground()`,資料存在本機檔案系統的 SQLite 檔
- **Web**:`WasmDatabase.open()`,依瀏覽器支援自動選擇儲存方式(OPFS / IndexedDB / 記憶體),需要 `web/sqlite3.wasm` 與 `web/drift_worker.dart.js` 兩個檔案才能運作
- 兩邊共用同一份 `database.dart` schema 定義,靠 conditional import(`if (dart.library.html)`)在編譯時分流,不用寫兩套邏輯

### 7.5 為什麼這樣設計

- **Repository pattern**(`card_repository.dart`)讓畫面完全不碰 SQL,之後要換資料庫或加快取都只要動這一層
- **拉霸邏輯抽成純函式**(`daily_roll.dart`)不吃資料庫,單元測試可以跑一萬次驗證機率分布,不用真的操作資料庫
- **SM-2 演算法獨立成 `scheduler.dart`**,規格明確要求不能動,所以特別做成零依賴的純函式,其他任何改動都不會不小心影響到它
- **`isIntroduced` 欄位**是整個「拉霸決定進度」機制的核心:卡片生成/匯入時預設不出現在複習佇列裡,只有被拉霸選中才會開始計入 SM-2 排程,這樣「新字量」才能真的由拉霸控制,而不是使用者自己決定要學哪些字

---

## 8. 目前待辦 / 已知限制

1. **30 個內建單字清單還沒經過你確認**(`assets/decks/starter_deck.json`)—— 規格書明確要求這步要停下來問
2. **AI 生成功能還沒有實際金鑰可測試** —— 邏輯跟錯誤處理都做完了,等你要串的時候補 `.env` 裡的 `AI_API_KEY` 即可
3. **`web/sqlite3.wasm` 的來源是 drift devtools 附帶的版本,不是官方明講「給 WasmDatabase 用」的正式管道** —— 目前看起來能跑,但建議之後有空找官方更明確的下載方式再核對一次版本
4. **PWA manifest(圖示、名稱、可安裝到主畫面)還沒調整** —— 規格書列為施工範圍外的第 10 步
5. **`lib/widgets/flashcard.dart` 目前沒有畫面在用** —— 規格書要求的翻卡元件還在,但複習流程改成測驗模式後用不到,如果之後想要「先翻卡看例句、再選答案」的混合模式,這個元件可以重新接回去
