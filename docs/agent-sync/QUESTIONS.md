# QUESTIONS.md

> 格式:`## [未回答] 問題標題`,回答後請改成 `[已回答]` 並在下面補結論。

---

## [未回答] 完成畫面的「單字庫快用完了,去生成新的吧」在 C 之後變成死路

C 拿掉了 Library 的 AI 生成入口(按鈕、`_goToGenerate`、import 全部移除,
`generate_screen.dart`/`ai_service.dart` 檔案本身保留但已無法從 UI 到達)。

但 `review_screen.dart` 的完成畫面裡,`_warehouseExhausted` 為 true 時還是會
顯示「單字庫快用完了,去生成新的吧」(E 已翻成
`Your word bank is running low`)——這句話字面上引導使用者去生成新單字,
但現在整個 App 已經沒有任何入口能到那個畫面了,變成一句指向死路的提示。

另外 SPEC 15.4 對完成畫面的內容規定是「只有三樣:caption 文案、
「You know N words」、HOME 按鈕」,這句警告字面上是第 4 樣內容,
不在這三樣清單裡。

這輪 B/C/E 的範圍都沒有明確指示要處理這句話,我沒有動它(只做了機械式的
style token 替換,文字內容和顯示邏輯完全沒改)。想請你們決定:

1. 乾脆拿掉這句提示(讓完成畫面回到嚴格的三樣內容)?
2. 保留但改措辭,不要再提「生成」(例如單純提示字卡量偏低)?
3. 維持現狀,等以後 AI 生成後端代理做完、入口重新開放時再說?

我傾向 1,但這是產品決策,不是我能定的,先寫在這裡等裁示。

---

## [已回答] Shawn 實測:每次打開 App 都沒有記憶效果,沒有需要複習的字

- **Shawn 原話:**「我實測了 他現在是不是沒有記憶效果 為什麼每次開所有東西都
  重新 沒有需要複習的」
- **情境:** Shawn 本機用 `flutter run -d chrome` 測試,每次重開 App,
  資料看起來都像重新開始,沒有卡片累積到期需要複習。

### ✅ 診斷結論

**不是資料庫寫入邏輯壞掉,是本機測試方式的問題。**

`flutter run -d chrome` 沒有指定 `--web-port` 時,每次啟動會挑一個不同的
隨機 port。瀏覽器的持久化儲存(IndexedDB / OPFS,Drift Web 資料庫存在
這裡)是綁定在「origin」上,origin = protocol + host + **port**。port
一變,對瀏覽器來說就是全新的網站、全新的空儲存空間,跟資料庫本身有沒有
正確寫入完全無關。

**這個問題只在本機 `flutter run -d chrome` 測試時會發生,部署到 GitHub
Pages 之後不會**——`https://sssh27.github.io/VOC-daily/` 是固定網址,
origin 不會變。

**已做的事:**

1. `lib/data/database_connection/connection_web.dart` 加了一行 debug
   log,啟動時瀏覽器 console 會印出 `DB storage: ..., missing features:
   ...`,可以直接確認 Drift 實際選了哪種儲存方式(如果是 `inMemory`
   才是真的沒有持久化,是另一個問題;`indexedDb`/`opfs` 開頭代表持久化
   本身沒問題)。
2. 完整診斷細節記在 `PROGRESS.md`「補丁:Shawn 回報...」那節。

**建議 Shawn 本機測試時的做法:**

```
flutter run -d chrome --web-port=8080
```

每次都用同一個指令(同一個 port)重開、同一個分頁重新整理,資料應該就在。
或者直接跳過本機持久化測試,等 push 部署後測正式網址。

---

## [已回答] `word_highlight.dart` 的「詞形變化推測」分支實際上永遠不會執行到

- **情境:** 這輪(v7)第一次幫 `highlightWordSpans()` 寫單元測試
  (`test/example_match_test.dart`)才發現:SPEC.md 6.3 第 3 條規則
  (「word 不含空格時允許詞形變化,例如 `procrastinate` 對到句中的
  `procrastinating`」)對應的 `tokenRegex` fallback 分支
  (`lib/widgets/word_highlight.dart` 第 50–60 行)實際上**永遠不會被觸發**。

  原因:前面的 `lowerExample.indexOf(lowerWord)`(第 47 行)是原始子字串
  搜尋,只要 word 是句中任何 token 的字首(這正是詞形變化推測想抓的情況,
  例如 "procrastinating" 以 "procrastinate" 開頭),`indexOf` 就會直接
  找到,而且回傳的長度固定是 `word.length`,不會延伸到整個 token。也就是
  說實際結果是**只標粗 word 自己的長度**(例如 word=`clean`、句中
  `cleaning` → 只有 `clean` 4 個字母變粗體,`ing` 不會),SPEC
  文件裡舉的 `procrastinating` 例子其實從來沒有真的被 fallback 分支
  處理過——因為 `procrastinate` 本身結尾是 e,`procrastinating` 是去 e
  加 ing,`indexOf("procrastinate")` 在 `procrastinating` 裡根本找不到
  (兩者中間就差在有沒有那個 e),所以這個特定例子反而會落到 4.
  「整句原樣顯示」,不會有任何粗體。

- **目前狀態:** 這個分支是死碼(dead code),不會造成錯誤或崩潰,只是達不到
  文件宣稱的效果。我這輪沒有動這段邏輯(不確定產品意圖,依 CLAUDE.md
  規則停下來問),`test/example_match_test.dart` 裡如實記錄了現在的真實
  行為(只標 word 自己的長度),沒有照 SPEC 文件寫的行為去斷言。

- **選項:**
  1. 拿掉 `tokenRegex` fallback 分支(反正打不到),SPEC 6.3 第 3 條規則
     改成單純說明「word 是某個較長字首時只會標到 word 自己的長度」
  2. 修正比對邏輯,讓「word 是句中某個 token 字首」時能抓到整個 token
     (但這樣 word=`run` 遇到句中 `running` 也會整個標粗,可能不是所有
     場景都想要;而且如果要做「去 e 加 ing」這種真正的詞形還原,SPEC 6.3
     本文明確禁止在程式裡猜這個)
  3. 維持現況,反正實際案例都可以用 `exampleMatch` 精確指定,這個分支
     只是聊勝於無的保底,不值得為它加複雜度
- **我的傾向:** 選項 3。`exampleMatch` 已經是這類情況的正式解法
  (v6 就是為此新增的),這個舊分支保留著沒有壞處也沒有實際效用,
  拿掉的話要重新過一輪回歸測試才敢動,投報率不高。

### ✅ 結論:選項 1 —— 移除該分支,並修正 SPEC 6.3 的描述

先肯定這個發現。你停下來問而不是自己改,是對的。

#### 我驗算過,結論比你說的更強:那個分支在數學上不可能被執行到

fallback 的觸發條件是「句中某個 token 以 `word` 開頭」。
但只要有任何 token 以 `word` 開頭,`word` 本身就必然是整句的子字串,
前面那行 `lowerExample.indexOf(lowerWord)` 一定會先找到並回傳。

**兩個條件互斥,fallback 永遠輪不到。** 這不是「目前剛好沒踩到」,是結構上不可達。

#### 為什麼推翻你的選項 3

你的顧慮(動它要重跑回歸測試)在一般情況下是合理的工程判斷。但這裡不成立:

**既然證明不可能被執行到,移除它在定義上不可能改變任何行為。回歸風險是零。**

而留著的代價是實質的:SPEC 6.3 目前描述了一個不存在的功能。
**死碼 + 錯誤文件,比單獨任何一個都糟糕** —— 下一個讀規格的人(很可能是
另一個 agent,或幾個月後的你自己)會以為那個功能存在,然後基於錯誤前提做決定。

#### 順帶否決選項 2

「把粗體延伸到整個 token」看起來是個修正,但會過度比對:
`word=cat` 會把句中的 `category` 整個標粗,`word=run` 會標到 `runway`。
誤判比現在更糟,不做。

#### 要動的

1. `lib/widgets/word_highlight.dart` 移除 `tokenRegex` fallback 分支
2. SPEC 6.3 的比對規則改成三段:`exampleMatch` → `word` 精確比對 → 整句原樣顯示,
   並明確說明「`word` 是較長單字的字首時,只會標到 `word` 自己的長度」
3. `test/example_match_test.dart` 補一個測試,鎖住這個行為:
   `word=clean` + 例句含 `cleaning` → 只有 `clean` 五個字母是粗體

你這輪在測試裡如實記錄真實行為而不是照文件斷言,做法正確。

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
