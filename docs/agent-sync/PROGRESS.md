# PROGRESS.md

> 寫這份文件的人:老二(實作者)
> 目的:對照 SPEC.md,誠實記錄目前專案的真實狀態,包含已完成、未完成、跟已知偏離規格的地方。
> 詳細變動歷程另見 `IMPLEMENTATION_REPORT.md`(這份是給人看的完整報告,PROGRESS.md 是給老大快速對照 SPEC 用的結構化版本)。

---

## 已完成(對照 SPEC.md 章節)

| SPEC 章節 | 項目 | 狀態 | 備註 |
|---|---|---|---|
| 2.1 | Web WASM 資料庫設定 | ✅ 完成,但有疑慮 | 見下方「已知偏離 SPEC 之處」#2 |
| 4.2 | Cards 表加 `isIntroduced` | ✅ 完成 | |
| 4.3 | DailyRolls 表 | ✅ 完成 | |
| 5.1–5.5 | 積壓量、拉霸權重、保護機制、`daily_roll.dart`、引入新卡流程 | ✅ 完成 | |
| 5.6 | 複習佇列組成 | ✅ 完成 | |
| 5.7 | 沒做完不懲罰 | ✅ 完成(沒實作任何懲罰機制) | |
| 6.1 | 首頁 | ✅ 完成 | 沒有顯示積壓數字/連續天數/完成率,符合規格禁止事項 |
| 6.2 | 拉霸畫面 | ✅ 完成 | |
| 6.3 | Flashcard 元件(翻卡+挖空) | ✅ 完成,但**目前沒有畫面在用** | 見下方偏離 #1 |
| 6.4 | 複習畫面 | ⚠️ **已完成,但整個互動模式偏離 SPEC** | 見下方偏離 #1,這是最重要的一項,需要老大確認方向 |
| 6.5 | 牌組列表 | ✅ 完成 | |
| 6.6 | AI 生成畫面 | ✅ 邏輯完成,**未接真實 API key,無法實測** | |
| 7 | 內建牌組匯入 | ✅ 機制完成,⚠️ 內容(30 字清單)未經確認 | 見 QUESTIONS.md |
| 8 | 檔案異動清單 | ✅ 全部檔案都有建立/修改,清單見下方 | |
| 9.1 | 單元測試 | ✅ `flutter test` 全過(scheduler 4 個 + daily_roll 6 個 = 10 個) | |
| 9.2 | 手動驗收流程 | ⚠️ 部分驗證過(App 能啟動、拉霸動畫、Web 持久化) | 第 7 項「複習畫面正面例句正確挖空,翻面顯示完整例句」因為互動模式改了,**這條驗收標準已經不適用**,需要老大重新定義 |

---

## 尚未完成

1. **`sqlite3.wasm` / `drift_worker.dart.js` 的正式來源驗證** —— 目前是從本機 pub cache 裡 `drift-2.34.3` 套件內附的 devtools 用檔案複製過來的,不是官方文件明講「給 `WasmDatabase.open()` 用」的正式發布管道(因為 drift GitHub release 頁面目前已經不附這兩個編譯好的檔案)。能跑,但沒有百分之百把握版本語意完全對得上。
2. **AI 生成功能沒有真實 API key 可測試** —— 錯誤處理(缺金鑰/網路錯誤/JSON 格式錯誤三種分類)邏輯都寫了,但沒有實際打過 API,無法確認成功路徑真的能正常運作。
3. **SPEC 第 10 節第 10 步 — PWA manifest 調整**(圖示、名稱、可安裝到主畫面)完全沒動,SPEC 本身也註明這不在本次施工範圍。
4. **Git commit / push** —— 目前所有變動都還沒 commit,`git status` 顯示一堆 modified 檔案沒進 repo。等老大看過這份 PROGRESS.md、確認方向後再依「一個步驟一個 commit」的規則補上。

---

## 已知偏離 SPEC 之處(需要老大特別注意)

### 1. 複習畫面(6.4)整個互動模式換掉了

**SPEC 原本要的:**
翻卡(正面挖空例句 → 點擊翻面看完整例句+中譯)→ 翻面後出現四個評分按鈕(忘記了=0 / 有點難=3 / 普通=4 / 簡單=5)→ 呼叫 `reviewCard(state, quality)`。

**現在實際做的:**
不翻卡。直接顯示英文單字 + 完整例句(單字本身用粗體標示,不挖空)+ 四個中文意思選項(1 正確 + 3 個隨機干擾項)。答對算 quality=5,答錯算 quality=0,直接顯示正確答案並自動跳下一題,沒有讓使用者手動評「有多難」。

**為什麼會這樣:** 這是 Shawn(專案擁有者)在畫面做出來之後,看了實際成品覺得體驗不對,直接要求改的:
1. 先是要求把翻卡+四個難度按鈕整個換成「看起來相似的單字四選一」(後來釐清是看單字選中文意思,不是選相似單字)
2. 接著發現例句還是挖空但單字已經顯示在題目上方,挖空沒有意義,要求改成例句完整顯示、單字粗體

**這造成的實際影響:**
- `reviewCard()` 本身(scheduler.dart)完全沒被改動,規格禁止的那條線沒有跨過
- 但 SM-2 排程現在只會吃到 quality=0 或 5 這兩個極端值,`scheduler.dart` 裡 quality=3、4 對應的「有點難/普通」中間地帶邏輯,實際上永遠不會被觸發到 —— 演算法碼還在,但複習畫面的呼叫方式讓它形同虛設
- `lib/widgets/flashcard.dart`(6.3 規格要求的翻卡元件)還是照規格寫完了,只是現在沒有任何畫面在呼叫它,是「寫好但未使用」的狀態
- SPEC 9.2 手動驗收第 7 條「複習畫面的正面例句有正確挖空,翻面後顯示完整例句與中譯」已經不適用於現在的畫面

**我的立場:** 這是 Shawn 直接當場要求的改動,不是我自己偏離規格,但因為 SPEC.md 是 single source of truth,而且這條改動影響到 SM-2 只吃兩個極端 quality 值這件事,我覺得需要老大明確表態:要嘛正式把 SPEC.md 6.4 更新成四選一測驗版本,要嘛我們討論要不要保留翻卡評分模式當作另一種複習模式(兩者並存,使用者可選)。在老大回覆之前我不會再進一步改這塊。

### 2. Web WASM 檔案來源非官方文件明講的正式管道

見上方「尚未完成」#1。功能上目前可以正常運作(有跑起來、有持久化),但來源不是 100% 照官方指引走,想請老大評估這樣是否可接受,或需要換更正式的取得方式。

---

## `flutter test` 結果

```
00:03 +10: All tests passed!
```

10 個測試(`test/scheduler_test.dart` 4 個 + `test/daily_roll_test.dart` 6 個)全部通過,`scheduler_test.dart` 裡的斷言完全沒被改動過。

---

## 動了哪些檔案

完整清單見 `IMPLEMENTATION_REPORT.md` 第 6 節「重要檔案現況總表」。簡要版:

- **新增**:`lib/data/card_repository.dart`、`lib/data/database_connection/{connection_native,connection_web}.dart`、`lib/logic/daily_roll.dart`、`lib/services/starter_deck_loader.dart`、`lib/screens/{daily_roll_screen,decks_screen}.dart`、`lib/providers.dart`、`assets/decks/starter_deck.json`、`test/daily_roll_test.dart`、`web/drift_worker.dart`(+ 編譯出的 `.js`)、`web/sqlite3.wasm`
- **修改**:`lib/data/database.dart`、`lib/main.dart`、`lib/screens/{home_screen,generate_screen,review_screen}.dart`、`lib/widgets/flashcard.dart`、`lib/services/ai_service.dart`、`pubspec.yaml`
- **完全沒動**:`lib/logic/scheduler.dart`、`test/scheduler_test.dart`
- **刪除**:`test/widget_test.dart`(`flutter create` 預設模板測試,引用不存在的 `MyApp` 類別,會讓 `flutter test` 編譯失敗,SPEC 檔案清單裡也沒有這個檔案)

---

## 下一步建議

先不寫新功能,等老大看過這份文件跟 `QUESTIONS.md` 回覆之後再繼續。
