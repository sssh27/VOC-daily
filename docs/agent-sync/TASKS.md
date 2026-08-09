# TASKS.md

> 國王餅(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。

---

## 上一輪 review 結果

v5 全部完成,Shawn 本機測試通過。核心循環已完整可用。

**這一輪的重點是內容導入。時間敏感:Shawn 過幾天要搭郵輪,需要這批字能用。**

---

## A. 【最優先】多牌組載入機制

`docs/SPEC.md` 第 7 節已改版為 **v6**,請先讀。

我已經產好一個新牌組:`assets/decks/cruise_travel.json`(郵輪與旅遊實用,166 張)。
但目前的 loader 載不進去,有兩個必須修的限制:

| 現況 | 問題 |
|---|---|
| 只吃寫死的 `starter_deck.json` | 新牌組進不來 |
| `hasAnyDeck()` 為 true 就整個跳過 | Shawn 資料庫已有資料,永遠拿不到新牌組 |

### 修法

1. `lib/services/starter_deck_loader.dart` → 改名 `lib/services/deck_loader.dart`,
   class `StarterDeckLoader` → `DeckLoader`
2. 維護內建牌組清單:
   ```dart
   static const _deckAssets = [
     'assets/decks/starter_deck.json',
     'assets/decks/cruise_travel.json',
   ];
   ```
3. 方法改名 `importIfEmpty()` → `importMissingDecks()`
4. 逐一檢查:**依 `Deck.name` 判斷是否已存在,不存在才匯入**
5. **已存在的牌組不要覆蓋、不要更新** —— 會洗掉 Shawn 的學習進度
6. 單一牌組匯入失敗時記錄錯誤但不要 crash,繼續處理下一個
7. `pubspec.yaml` 的 assets 加入 `assets/decks/cruise_travel.json`
8. `main.dart` 及其他呼叫端同步更新

### 需要新增 repository method

`hasAnyDeck()` 不夠用,需要能依名稱查詢,例如:

```dart
Future<bool> deckExistsByName(String name);
```

---

## B. 測試

1. `deckExistsByName()` 正確回傳存在/不存在
2. 空資料庫 → 兩個牌組都被匯入
3. 已有「入門常用字」→ 只匯入「郵輪與旅遊實用」,原牌組的卡片數與進度不變
4. 兩個牌組都存在 → 不重複匯入,卡片總數不變
5. asset 路徑不存在時不會 crash,其他牌組照常匯入

`flutter test` 必須全綠,`test/scheduler_test.dart` 依然**禁止修改**。

---

## C. 驗證

修完後請在 `PROGRESS.md` 註明需要 Shawn 本機驗證的項目:

1. `flutter run -d chrome` 啟動後,單字庫頁面應看到**兩個**牌組
2. 「郵輪與旅遊實用」卡片數為 **166**
3. 「入門常用字」的已學進度沒有被重置
4. 轉盤 → 開始,新字會從兩個牌組混合出現

---

## D. 不要做的事

- **不要刪除** `lib/services/ai_service.dart` 或 `lib/screens/generate_screen.dart`。
  正式版本不依賴它們,但保留作為開發階段的產字工具。檔案裡的警告註解也不要刪。
- **不要修改** `assets/decks/cruise_travel.json` 的內容。有錯誤請寫進 `QUESTIONS.md`,
  由國王餅修正。
- 不要自行往下做 PWA manifest 或 SPEC 第 10 節其他步驟。

---

## E. Commit

1. `refactor: rename starter deck loader to multi-deck loader`
2. `feat: import missing decks by name instead of skipping when db non-empty`
3. `feat: add cruise and travel vocabulary deck (166 cards)`
4. `test: cover multi-deck import behaviour`

`git push` 若環境沒有認證,在 `PROGRESS.md` 註明,由 Shawn 本機執行。

---

## 完成後

更新 `PROGRESS.md` 後停下來等 review。

---

## F. 【追加】`exampleMatch` 欄位支援

我在產內容時驗證發現:166 張裡有 10 張的粗體比對會失效,幾乎全是片語動詞的時態變化
(`hang out` → `hung out`、`run into` → `ran into`、`look forward to` → `looking forward to`)。
含空格的片語無法套用現有的詞形變化推測。

**解法:JSON 加選填欄位 `exampleMatch`,直接標明例句中要標粗的字串。**
已經補進 `cruise_travel.json` 的那 10 張。

`docs/SPEC.md` 的 4.2、6.3、7.3 已更新,請照著做:

### F1. 資料庫

`Cards` 表加欄位 `exampleMatch`(nullable text),`schemaVersion` 遞增,
`onUpgrade` 加對應分支。改完記得跑:

```
dart run build_runner build --delete-conflicting-outputs
```

### F2. 比對邏輯

`lib/widgets/word_highlight.dart` 的比對改成依序判斷:

1. 有 `exampleMatch` → 精確比對這個字串,**優先於所有其他規則**
2. 沒有 → 用 `word` 大小寫不敏感比對
3. 仍找不到且 `word` 不含空格 → 現有的詞形變化推測
4. 都找不到 → 整句原樣顯示

**不要**在程式裡實作不規則動詞表或詞形還原規則。那是刻意避開的方向,
理由寫在 SPEC 6.3。

### F3. Loader 與 repository

`deck_loader.dart` 解析 `exampleMatch`,`createDeckWithCards()` 簽章加對應參數
(AI 生成的卡片傳 null)。

### F4. 測試

1. 有 `exampleMatch` 時,標粗的是該字串而非 `word`
2. `exampleMatch` 不在例句裡時,不 crash,退回整句原樣顯示
3. 沒有 `exampleMatch` 時,現有的三段式邏輯行為不變(回歸測試)
4. 片語 `hang out` + `exampleMatch: "hung out"` + 例句 `We hung out...` → 正確標粗
