# QUESTIONS.md

> 格式:`## [未回答] 問題標題`,回答後請改成 `[已回答]` 並在下面補結論。

---

## [已回答] 複習畫面(6.4)要不要正式改成四選一測驗?

- **情境:** SPEC 6.4 原本定義的是「翻卡(挖空例句→翻面看完整例句+評分按鈕:忘記了/有點難/普通/簡單,對應 quality 0/3/4/5)」。實際畫面做出來後,Shawn 直接要求改成「不翻卡,看單字+完整例句(單字粗體)+四選一中文意思選項,答對 quality=5、答錯 quality=0」。現在 repo 裡的 `review_screen.dart` 是四選一版本,不是 SPEC 原本寫的翻卡版本。`lib/widgets/flashcard.dart`(翻卡元件)還在,但沒有任何畫面在用它。
- **選項:**
  1. 把 SPEC.md 6.4 正式改成四選一測驗版本
  2. 維持 SPEC 原本的翻卡+四按鈕設計
  3. 兩種模式都留著,讓使用者在設定裡切換
- **你的傾向:** 選項 1。

### ✅ 結論(v3 定案,取代先前的 v2 分流方案)

**保留四選一,加一個獨立的「忘了」按鈕,再加反應時間自動分級。**

我原本提的「依 repetitions 分流成四選一 / 回想模式」**已作廢**,不要實作。
Shawn 否決了回想模式,理由充分:回想難度高 → 答錯變多 → interval 被 reset →
同一個字反覆回到佇列,複習量會膨脹。他不想被同一個字反覆糾纏。

#### 定案規格

見 `docs/SPEC.md` 6.3 / 6.4(已更新為 v3)。摘要:

| 使用者行為 | quality |
|---|---|
| 按「忘了」 | 0 |
| 選錯 | 0 |
| 選對,3 秒內 | 5 |
| 選對,3–8 秒 | 4 |
| 選對,超過 8 秒 | 3 |

#### 為什麼這樣能解決原本的問題

我先前指出純四選一的隱憂是「25% 亂猜命中 → 記 quality=5 → interval 推很遠 →
不會的字被排到很久以後」。這版用兩個機制處理:

1. **「忘了」按鈕給了不猜的出口。** 使用者不確定時有誠實選項,不必被迫猜。
   (Shawn 已表明這是他個人自用的 App,不需要防範使用者刻意亂猜,所以這個
   前提可以成立。)
2. **反應時間分級。** 猶豫很久才答對 → quality 3 → interval 只有小幅成長。
   即使猜對了通常也伴隨較長的思考時間,會被自動降級。

另外補一個讓人安心的事實:SM-2 的前兩次複習 interval 是固定的
(`repetitions == 0` → 1 天,`repetitions == 1` → 6 天),與 quality 無關。
quality 在前兩次只會累積到 easiness。所以猜測造成的排程偏差要到第三次複習
之後才會顯著,風險比想像中低。

#### 要動的檔案

- `lib/widgets/flashcard.dart` → **刪除**(翻卡模式否決,不要留死 code)
- `lib/widgets/question_card.dart` → **新增**(不翻面的題目卡,見 SPEC 6.3)
- `lib/screens/review_screen.dart` → 加「忘了」按鈕、加 Stopwatch 計時分級、
  答題後顯示 `exampleZh`、改善 distractor 選取
- `test/` → 新增反應時間分級的測試(見 SPEC 9.1 補充)

---

## [已回答] Web WASM 檔案(`sqlite3.wasm` / `drift_worker.dart.js`)來源是否可接受?

- **情境:** `sqlite3.wasm` 是從本機 pub cache 裡 drift 套件的 devtools build 複製來的,不是官方指定給 `WasmDatabase.open()` 用的版本。
- **你的傾向:** 選項 1(接受現況)但保留疑慮。

### ✅ 結論:選項 1,但排進上線前的待辦

**現在照用,不要停下來處理。** 理由:devtools 附的 wasm 跟官方 release 的差別主要在編譯選項與 VFS 支援,會出問題的是多分頁同步、OPFS fallback 這類冷門路徑。你現在單人、單分頁開發,踩不到。為了這個卡住進度不划算。

**但要記錄成技術債。** 正確的官方來源是:

- `sqlite3.wasm` → https://github.com/simolus3/sqlite3.dart/releases
- `drift_worker.dart.js` → https://github.com/simolus3/drift/releases

注意:兩個檔案要取**同一個 drift release 對應的版本**,混版會有難查的問題。

**動作:** 在 `PROGRESS.md` 開一個「技術債」區塊記下這件事,標註「PWA 上線前必須換成官方 release 檔案並回歸測試」。現在不用做。

---

## [已回答] 內建牌組 30 字清單要怎麼走確認流程?

- **你的傾向:** 選項 1(補走確認流程)。

### ✅ 結論:選項 2,我直接 review 過了,批准使用,但要修 1 個地方

清單我看過了,選字水準沒問題——B1–B2 區間、日常實用、不會太冷僻,例句自然且中譯正確。可以用。

**必須修正:**

- **`postpone`(延後;延期)與 `procrastinate`(拖延)語意太近。** 在四選一裡如果同時出現會造成不公平的假陰性。二選一處理:
  - (a) 把 `postpone` 換成語意距離較遠的字,或
  - (b) 保留但把 meaning 改寫得更有區別度,例如 `postpone` → `延後(把預定時間往後挪)`、`procrastinate` → `拖延(該做卻遲遲不做)`

  **建議選 (b)**,因為這兩個字本來就容易混淆,寫清楚反而有教學價值。

  **另外**:v3 規格在卡片 JSON 加了選填欄位 `avoidWith`,請幫 `procrastinate`
  和 `postpone` 互相加上,確保它們不會同時出現在同一題的選項裡。

**可以不管:**

- `convenient` / `inconvenient` 同時存在。四選一時會變送分題,但反義詞成對出現對記憶有幫助,利大於弊,保留。

---

## [新增待辦] 立刻 commit

你目前所有變動都還沒進 git(`git status` 一堆 modified)。這是幾天的工作量,沒有版控保護。

**請優先做這件事,在動任何新 code 之前:**

1. 先把現況 commit 起來(不用等重構完),訊息可用:
   `feat: implement daily roll, web wasm db, quiz review screen, starter deck`
2. push 到 `https://github.com/sssh27/VOC-daily`
3. 之後再照「一個步驟一個 commit」的規則做上面的複習模式重構

先存檔再改東西,不要反過來。
