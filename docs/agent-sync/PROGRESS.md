# PROGRESS.md

> 寫這份文件的人:聖多諾黑(實作方)
> 目的:對照 `docs/SPEC.md`,誠實記錄目前專案的真實狀態。
> 舊版完整報告在 `docs/agent-sync/archive/IMPLEMENTATION_REPORT.md`。

---

## 這一輪(視覺改版第一批)做了什麼——⚠️ 卡在缺字型檔,只做完 A 和 D

先看設計稿(`docs/design/` 九張圖)和 `docs/SPEC.md` 第 14、15 節,兩者都讀完
才開始動工,確認過設計稿與 SPEC 衝突時以 SPEC 為準。

### A. 首頁背景金屬珍珠 ✅ 完成

- 新增 `lib/widgets/floating_pearls.dart`:`FloatingPearls` widget,內部
  自己管 4 個 `AnimationController`,整個包在 `IgnorePointer` 裡。
- 位置/大小照 SPEC 14.3 的表:#1 直徑 200、`left: -70px`、`top: 12%`;
  #2 直徑 140、`right: -70px`、`top: 55%`;#3 直徑 90、`left: 8%`、
  `top: 74%`;#4 直徑 56、`right: 14%`、`top: 20%`。水平用 px(#1/#2,
  故意讓它們被邊緣裁切)或畫面寬度百分比(#3/#4),我用一個 `_PearlSpec`
  資料類統一處理兩種單位。
- 動畫照 SPEC 14.5:`Curves.easeInOut`(不是 linear)、
  `AnimationController(...)..repeat(reverse: true)`,四顆週期 22/18/25/15
  秒(互質,不會同步),起始相位錯開(`controller.value` 初始設
  0.0/0.25/0.5/0.75)。
- `AnimatedBuilder` 的 `child` 參數有用上,`Image.asset` 只建立一次傳進去
  快取,`builder` 每幀只重建 `Positioned`,不重建圖片。
- `dispose()` 釋放全部 4 個 controller。
- `MediaQuery.of(context).disableAnimations == true` 時完全不呼叫
  `repeat()`,珍珠停在 `initialPhase` 對應的靜止位置,不啟動 controller。
- 素材路徑用 `assets/images/pearl.png`(沒有手動指定 2.0x/3.0x),沒有加
  任何 `BoxShadow`/`ColorFiltered`/`Opacity`。
- `home_screen.dart`:`Scaffold.body` 外層包一層 `Stack`,
  `FloatingPearls()` 放第一個 child(最底層),原本的 `Center(...)` 整個
  不動地放第二個 child。中央主氣泡的大小、位置、樣式一個字元都沒改。

**驗收(SPEC 14.7 八點)—— 前 3、5、6、7、8 點我從程式碼結構可以確認,
第 1、2、4 點需要你實際跑起來用眼睛看,我這邊沒有 Flutter/瀏覽器環境:**

| # | 項目 | 狀態 |
|---|---|---|
| 1 | 4 顆銀色金屬珍珠,大小明顯不同、分布不對稱 | 程式碼位置/大小照表寫死,**需要你跑起來確認實際畫面** |
| 2 | 其中 2 顆被畫面左右邊緣裁切 | #1(`left:-70px`)、#2(`right:-70px`)照 SPEC 設定,**需要你確認裁切比例看起來對不對** |
| 3 | 珍珠邊緣乾淨,沒有灰色外圈或方形邊界 | ✅ 沒有加任何濾鏡/陰影,直接用素材原圖,程式碼層面確認 |
| 4 | 珍珠緩慢上下飄浮,四顆節奏不一致 | 週期 22/18/25/15 秒互質 + 相位錯開,**這條 SPEC 特別要求用眼睛看,麻煩你實測** |
| 5 | 點擊珍珠位置,下方按鈕仍能正常觸發 | ✅ 整個 `FloatingPearls` 包在 `IgnorePointer` 裡,不會攔截點擊 |
| 6 | 珍珠沒有蓋住任何文字或按鈕 | ✅ 珍珠 #3(`top:74%`)刻意避開 START 按鈕與文字位置,若你實測發現小螢幕(高度 < 600dp)被壓到,把 #3 的 `top` 調到 78%,不要動文字位置(SPEC 14.4 已經預留這個備案) |
| 7 | 中央主氣泡、字級、顏色、間距與改版前完全相同 | ✅ 只在外面包了一層 `Stack`,`Center(...)` 內容完全沒動 |
| 8 | `flutter test` 全綠 | 沒有測試碰到 `HomeScreen`/`FloatingPearls`,理論上不受影響,**麻煩你本機跑一次確認** |

### D. 學習完成畫面改垂直置中 ✅ 已經是這樣,沒有改動程式碼

檢查 `lib/screens/review_screen.dart` 現在的完成畫面(`_buildCompletionContent`,
不是 TASKS.md 提到的 `_buildDoneMode`,那個名稱在目前的程式碼裡不存在)——
它已經是：

```dart
body: Center(
  child: !_completionInfoLoaded
      ? const CircularProgressIndicator()
      : _buildCompletionContent(context),
),
```

`Center` 包住一個 `mainAxisSize: MainAxisSize.min` 的 `Column`,這是
Flutter 裡讓內容在可用空間裡水平 + 垂直都置中的標準寫法,視覺效果跟
TASKS.md 描述的「外層 Column 加 `mainAxisAlignment: MainAxisAlignment.center`
並撐滿整個可用高度」是同一個結果,只是實作手法不同。

**我判斷這裡不需要改動**,所以沒有動這個檔案。我猜 TASKS.md 這段可能是
照 Stitch 設計稿(`05-study-complete.png`,靠上對齊、下方大片空白)寫的,
沒有對照到目前實際的程式碼——C 那段你自己也提到「先前根據設計稿判斷…
實際讀 code 之後發現有兩項是我誤判」,這應該是同一類狀況。

**麻煩你實際跑起來看一下這個畫面**,如果它現在看起來真的還是靠上對齊,
那代表有我沒看出來的其他原因(例如某個父層 widget 的約束問題),請告訴我,
我再深入查。如果它看起來已經是置中的,這項就當作已完成。

### ⚠️ B、C、E 卡住,原因:缺字型檔

`assets/fonts/` 目前完全是空的(不存在這個資料夾),沒有 Syne 或
Hanken Grotesk 的任何 TTF 檔。TASKS.md 已經預期到這個狀況,並指示
「先做 A 和 D,B/C 等檔案到齊再做」——所以我照做,B、C 都還沒動。

**E(介面文字改英文)我也一併保留**,雖然它本身不需要字型檔,但 TASKS.md
的執行順序明確寫「A → B → C → D → E,不要跳」,而且 E 的理由是
「B/C/D 會搬動這些字串的位置,先翻會白做兩次」——目前 C 還沒做(它會
拿掉 `decks_screen.dart` 的 AI 生成按鈕,改動那個檔案的結構),所以照順序
E 也還不該做。

**麻煩 Shawn 把 Syne 和 Hanken Grotesk 的 static TTF 檔放進
`assets/fonts/`**(記得是 `static/` 資料夾底下的固定字重檔,不是
`VariableFont` 版本,否則 Flutter 上字重會失效)。字型到齊後跟我說一聲,
我就接著做 B → C → E。

### Commit

這輪 2 個 commit:

1. `docs: sync CLAUDE.md, SPEC.md, TASKS.md for visual redesign round (v10); add design references`
2. `feat: add floating pearls background decoration to home screen`

（這份 PROGRESS.md 更新完會是第 3 個。）

**`git push` 一樣跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。

### 沒做的事

- B(設計系統 token)、C(拿掉 Library 的 AI 生成入口)、E(介面文字英文化)
  都卡在缺字型檔 + 執行順序,詳見上面說明
- `assets/decks/*.json` 沒有動
- Onboarding、Settings 畫面沒有做(依指示,規格還沒定案)
- Study 流程的互動邏輯、選項產生方式、計分方式沒有動

---

## 這一輪(v9,雜項清理)做了什麼

國王餅裁定「現在的狀態是可以部署了,這輪清最後的雜項」,三件事都做完了。

### A. 移除 `word_highlight.dart` 死碼

國王餅驗算後確認那個 `tokenRegex` fallback 分支**結構上不可能被執行到**
(不是「目前剛好沒踩到」),裁定選項 1(移除),推翻我上輪傾向的選項 3。
理由是死碼 + 錯誤文件比單獨任一個都糟,會誤導下一個讀規格的人。

- `lib/widgets/word_highlight.dart`:拿掉 fallback 分支,比對邏輯改回
  單純的三段式(`exampleMatch` → `word` 原始子字串比對 → 整句原樣)。
  函式簽章、行為(對現在還會用到的路徑而言)完全沒變——因為那個分支本來
  就打不到,移除它在定義上不可能改變任何現有測試的結果。
- `docs/SPEC.md` 6.3 改成三段式描述,明確寫出「word 是較長字的字首時只
  標到 word 自己的長度」,並記錄死碼移除的原因和版本(v9)。
- `test/example_match_test.dart` 裡原本「如實記錄現在的行為」那個測試
  的敘述改成「鎖定行為,v9 定案」,斷言本身沒變(`word=clean` 命中
  `cleaning` 時只有 `clean` 五個字母粗體),因為這就是移除死碼後的
  正式行為。

### B. 持久化診斷 log 降噪

`lib/data/database_connection/connection_web.dart` 的 `print(...)` 改成
`kDebugMode` 包住的 `debugPrint(...)`,拿掉 `// ignore: avoid_print`。
上一輪加這行是為了幫忙診斷 Shawn 回報的「沒有記憶效果」問題(其實是
`flutter run` 沒固定 port 導致 origin 每次都變),診斷邏輯本身國王餅
認可保留,只是不該讓正式版 console 一直印訊息。

### C. README.md 全面改寫

舊版還停在最早的骨架階段(Android 模擬器安裝流程、`.env` 設定 API key、
「上架 App Store 前必做」),跟現況完全對不上。改寫成:

- 專案簡介:拉霸決定新字量 + SM-2 排程 + 四選一測驗,PWA 部署
- 專案結構更新到目前實際的檔案清單(`daily_roll.dart` / `intro_queue.dart`
  / `milestone.dart` / `completion_messages.dart` / `deck_loader.dart` 等
  都補上了)
- 本機開發指令,**特別強調 `--web-port` 這個坑**(用一整段解釋原因,
  避免下一個人重踩)
- `build_runner` 提醒、`flutter test` 說明
- AI 產字工具改用 `--dart-define=AI_API_KEY=...`,全部移除 `.env` 相關
  說明
- 加上線上網址 `https://sssh27.github.io/VOC-daily/`
- 加一段指向 `docs/SPEC.md` / `docs/agent-sync/` / `CLAUDE.md` 的協作
  文件說明(舊版完全沒提到雙 agent 協作這件事)

### Commit

4 個 commit,跟 TASKS.md E 節建議的順序一致,多一個 docs 同步 commit
(SPEC.md/QUESTIONS.md/TASKS.md 你已經寫好但還沒進 git):

1. `docs: sync SPEC.md, QUESTIONS.md and TASKS.md (word-highlight dead code ruling)`
2. `refactor: remove unreachable morphology fallback in word highlighting`
3. `chore: gate db storage diagnostic behind kDebugMode`
4. `docs: rewrite README for current architecture and web-port caveat`

（這份 PROGRESS.md 更新完會是第 5 個。）

**`git push` 一樣跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。

### 沒做的事(依 D 節指示)

- `assets/decks/*.json` 沒有動
- SPEC 12.7 禁止清單一項都沒做
- `ai_service.dart` / `generate_screen.dart` 沒刪,警告註解沒動
- `.github/workflows/deploy.yml`、`web/manifest.json`、`web/icons/` 沒動

---

## 補丁:Shawn 回報「每次打開都沒有記憶效果,沒有要複習的字」

Shawn 實測後回報:每次重開 App,資料都像是重新開始,沒有卡片進入到期
複習。這不是這輪(v7)動到的東西造成的,是既有的 Web WASM 持久化設定
問題,先在這裡記錄診斷結果。

**最可能的原因:`flutter run -d chrome` 預設每次啟動用不同的 port。**

Drift 在瀏覽器裡的持久化儲存(IndexedDB / OPFS)是綁定在「origin」上的,
origin = protocol + host + **port**。`flutter run -d chrome` 沒有指定
`--web-port` 時,每次啟動 Flutter 開發伺服器會挑一個不同的隨機 port——
等於每次都是全新的 origin,瀏覽器看到的是全新的、空的儲存空間,跟資料庫
本身有沒有正確寫入完全無關。這完全符合「每次打開都像重新開始」的症狀。

**這件事只在本機 `flutter run -d chrome` 測試時會發生,部署到 GitHub
Pages 之後不會**,因為 `https://sssh27.github.io/VOC-daily/` 是固定網址,
origin 不會變。

**驗證方法(已經加進 code):** `lib/data/database_connection/connection_web.dart`
加了一行 debug log,啟動時瀏覽器 console 會印出
`DB storage: ..., missing features: ...`。如果 `chosenImplementation` 是
`inMemory`,才是真的完全沒有持久化(那會是另一個問題,例如
`sqlite3.wasm`/`drift_worker.dart.js` 版本不相容或瀏覽器功能缺失);
如果是 `indexedDb` 或 `opfs` 開頭的值,代表持久化本身是好的,單純是
port 換了。

**本機測試持久化的正確做法:** 固定 port 啟動,例如:

```
flutter run -d chrome --web-port=8080
```

每次都用同一個指令(同一個 port),重新整理或關掉再開同一個分頁,資料
就應該還在。也可以直接照 D 節建議測部署後的正式網址,那邊不會有這個問題。

---

## v7 補丁:Shawn 本機跑 `flutter test`/`flutter run` 抓到的錯誤

sandbox 沒有 Flutter SDK,這輪(v7)的程式碼我沒辦法自己編譯驗證,結果
Shawn 本機一跑就抓到 5 個問題,都已修正並補了 4 個 commit:

1. `lib/logic/completion_messages.dart` 的 `library` 指令寫在 `import`
   後面——Dart 規定 `library` 必須在所有 import 之前。
2. `lib/screens/review_screen.dart` 晃動動畫的 `const Tween(...)`——
   `Tween` 的建構子不是 const,寫 `const` 會編譯錯誤。
3. `test/app_settings_test.dart`、`test/replenish_test.dart` 同時
   `import 'package:drift/drift.dart'` 和 `flutter_test`,兩者都有
   `isNull`/`isNotNull`,名稱衝突。改成 `hide isNull, isNotNull`。
4. `test/example_match_test.dart` 裡「詞形變化推測」那個測試案例的期望值
   是錯的——**這順便挖出一個真的問題**:`word_highlight.dart` 裡負責
   詞形變化推測的 `tokenRegex` fallback 分支實際上永遠執行不到(前面的
   `indexOf` 原始子字串比對一定會先命中,而且只會標粗 word 自己的長度,
   不會延伸到整個 token)。已經照實際行為改測試斷言,並在
   `QUESTIONS.md` 開了一題給國王餅確認要不要處理這段死碼,**沒有**自作
   主張去改 `word_highlight.dart` 的比對邏輯。
5. `test/multi_deck_loader_test.dart` 的卡片數斷言是 v6 寫的,那時候
   `deck_loader.dart` 的預設清單只有 2 個牌組;這輪清單擴到 7 個之後
   斷言沒跟著更新(196 應該是 406)。已更新。

**這次教訓:** 我這邊沒有 Dart/Flutter 環境,只能靠讀程式碼推理,推理
不出編譯期規則(像 library 指令順序)或套件間的命名衝突。以後每輪做完
如果有任何不確定編不編得過的地方,會在回報裡主動提醒你優先跑
`flutter test`/`flutter run` 而不是等你自己發現。

---

## 這一輪(v7)做了什麼

依 `docs/agent-sync/TASKS.md` 的 G(最高優先)、A(5 個新牌組)、B(遊戲化與
回饋)、C(測試)完成,照建議順序 G1 → A → B → G2 做。

### ⚠️ 過程中發現的問題:`.gitignore` 排除了整個 `web/`

檢查 G2「確認 `.gitignore` 沒有排除 `web/icons/` 或 `.github/`」時發現實際
狀況比 TASKS.md 描述的更糟:`.gitignore` 把**整個** `/web/` 資料夾當成
`flutter create .` 產生的平台資料夾排除掉了(這行是專案早期就有的,那時
`web/` 確實只有自動產生的內容)。結果是 `git ls-files web/` 回傳**零筆**——
國王餅建好的 `manifest.json`、`icons/`、自訂 `index.html`、以及先前手動編譯的
`drift_worker.dart.js` / `sqlite3.wasm` 全部沒有進版控。`.github/workflows/`
也是零筆(不是被排除,單純沒被加過)。

如果沒抓到這個,GitHub Actions checkout 下來的 `web/` 會是空的,`flutter
build web` 要嘛失敗、要嘛用 Flutter 預設模板重新產生一份,拿到的絕對不是
國王餅準備好的 PWA 資源。**這會讓部署整個是假的——workflow 可能還是綠燈,
但產出的東西沒有正確的 manifest/icons/離線快取設定。**

已修正:`.gitignore` 拿掉 `/web/` 這行(改成只排除 android/ios/macos/
linux/windows),並把 `web/`、`.github/` 全部加進版控。同時把 `index.html`
的 `<title>`、`apple-mobile-web-app-title` 改成 `VOC-daily`、補上
`<meta name="theme-color">`,跟 `manifest.json` 對齊。

### G. 移除 dotenv + PWA 部署

- **G1** `main.dart` 移除 `dotenv.load()`,`pubspec.yaml` 移除 `.env` asset
  與 `flutter_dotenv` 依賴,`ai_service.dart` 改用
  `String.fromEnvironment('AI_API_KEY')`。本機要用 AI 產字工具:
  `flutter run -d chrome --dart-define=AI_API_KEY=sk-xxxx`。安全警告註解
  沒有刪。
- **G2** `web/manifest.json`、`web/icons/`、`.github/workflows/deploy.yml`
  是國王餅建好的,沒有重做或覆蓋,只確認+修正(見上面的 `.gitignore` 問題)。
  workflow 裡的 Flutter 版本 `3.44.8` 跟 `pubspec.yaml` 的 SDK 限制相容,
  `--base-href /VOC-daily/` 已經寫好。

**G3/G4 提醒(需要你手動做):**

1. GitHub repo → Settings → Pages → Source 選 **GitHub Actions**(不是
   Deploy from a branch),只需設定一次。
2. Push 後檢查 Actions workflow 是不是綠燈。
3. 手機瀏覽器開 `https://sssh27.github.io/VOC-daily/`,確認能正常顯示、
   選單有「加到主畫面」、加完桌面圖示能全螢幕開啟。
4. **開飛航模式測試**——這是郵輪情境最重要的一項,字庫是打包 asset、
   資料庫在瀏覽器本機,理論上斷網也能完整使用,但務必實測一次再出門。

### A. 註冊 5 個新牌組

`pubspec.yaml` 補 5 行 asset、`deck_loader.dart` 的 `_deckAssets` 補同樣
5 個路徑,`starter_deck.json` 依指示排到清單最後。內容(210 張)完全沒有
動過,是國王餅產好的。

### B. 遊戲化與回饋

- **B1 累計字數** `CardRepository.introducedCount()`(`isIntroduced==true`
  筆數),三處顯示:首頁轉盤下方一行小字、學習完成畫面主要位置較大字級、
  單字庫頁面頂端。
- **B2 里程碑** 新增 `AppSettings` 表(key/value,`schemaVersion` 4→5),
  沒有引入 `shared_preferences`。判斷邏輯抽成純函式
  `lib/logic/milestone.dart` 的 `milestoneToCelebrate({total, lastCelebrated})`,
  跨過多個門檻時只回傳最高的一個。完成畫面在 `_loadCompletionInfo()`
  裡呼叫一次(只在第一次進入 `_Phase.done` 時算,不會重複觸發),命中時
  寫回 `celebrated_milestone` 並顯示帶放大動畫的專屬文案。
- **B3 完成文案輪替** `lib/logic/completion_messages.dart` 的文案池
  (5 句,照抄 SPEC 12.4 建議池),`pickCompletionMessage()` 隨機挑一句;
  里程碑觸發時改用 `milestoneMessage(n)`,不用池子裡的句子。
- **B4 作答視覺回饋** `_ChoiceButton` 用 `TweenAnimationBuilder` 包一層:
  答對(使用者選對的那個)150ms 放大回彈;答錯(選錯的那個)200ms 左右
  晃動,正確答案同時變綠但不晃動;按「忘了」時 `isSelected` 恆為
  false,天然不會晃動,不需要額外判斷。沒有引入動畫套件。
- **B5 拉霸動畫漸慢定格** `home_screen.dart` 的 `_startRoll()` 從
  `Timer.periodic` 固定間隔改成 `while` 迴圈搭配 `Future.delayed`,
  delay 隨經過時間從 50ms 線性拉長到 300ms,總時長仍約 1.8 秒。
- **B6 音效** 沒做,依指示(見 SPEC 12.8)。

### C. 測試

sandbox 依然沒有 Flutter SDK,新增 3 個檔案:

| 檔案 | 案例數 | 涵蓋什麼 |
|---|---|---|
| `test/milestone_test.dart` | 8 | `milestoneToCelebrate()`:未達門檻不觸發、剛好達標觸發、已慶祝過不重複觸發、一次跨多階只回傳最高的、邊界值 |
| `test/completion_messages_test.dart` | 6 | 文案池非空/無空字串、隨機挑選的結果一定來自池子、多次呼叫會覆蓋到不同句子、里程碑文案帶正確數字、文案不含評比字眼(基本關鍵字檢查) |
| `test/app_settings_test.dart` | 8 | 累計字數與牌組數量無關、`AppSettings` 讀寫/覆蓋、key 不存在回傳預設值不 crash |

新增 22 個,加上 v6 累計的 50 個,合計預期 72 個。麻煩本機跑:

```
dart run build_runner build --delete-conflicting-outputs
flutter test
```

`database.dart` 這次加了 `AppSettings` 表,build_runner 這步必須跑。
`test/scheduler_test.dart` 完全沒動。

### 需要你本機驗證的項目(TASKS.md D 節)

1. 單字庫看得到 **7 個**牌組、總數 **406** 張
2. 既有牌組(如果你本機資料庫已經有「入門常用字」的學習進度)沒有被重置
3. 首頁轉盤下方顯示「你認識了 N 個字」
4. 答對有回彈、答錯有晃動、按「忘了」沒有晃動
5. 轉盤動畫是漸慢定格而非等速
6. 粗體抽查:`come down with` → `coming down with`、`try on` → `try it on`
   (這兩個字在新牌組裡,不在我這輪動過的檔案清單裡,值得抽查)

以及 G4(部署驗收,見上面 G3/G4 段落)。

### Commit

這輪切了 10 個 commit:

1. `fix: remove flutter_dotenv, use build-time --dart-define for AI key`
2. `fix: stop excluding web/ from git so PWA assets actually get deployed`
3. `docs: sync CLAUDE.md, SPEC.md and TASKS.md to v7`
4. `feat: add five themed vocabulary decks (210 cards)`
5. `chore: register new deck assets in pubspec and loader`
6. `feat: app settings table for milestone tracking`
7. `feat: show cumulative word count on decks screen`
8. `feat: show cumulative word count on home screen, ease the roll animation`
9. `feat: milestone celebrations, rotating completion captions, answer feedback animations`
10. `test: cover milestone logic, cumulative count, completion captions`

（這份 PROGRESS.md 更新完會是第 11 個。）

跟 TASKS.md F 節建議的切法不完全一樣,原因跟前幾輪一樣:`home_screen.dart`
跟 `review_screen.dart` 裡好幾個功能(累計字數顯示 vs 拉霸動畫;里程碑 vs
文案輪替 vs 答題動畫)彼此改在同一個檔案的鄰近程式碼,沒辦法乾淨切開,
硬切會產生編不過的中間 commit。commit 9 因此把 B2+B3+B4 併在一起,
commit message 裡有老實列出包含哪些東西。

**`git push` 一樣跑不了**(sandbox 沒有 GitHub 認證),需要你本機執行
`git push origin main`。

### 沒做的事

- SPEC 第 10 節第 10 步(PWA manifest 調整)本輪其實已經涵蓋在 G2 裡了,
  不算「沒做」,但沒有額外去動圖示美術(國王餅說目前是佔位版本,美術階段
  再換,不在這輪範圍)。
- `assets/decks/*.json` 內容完全沒有動過。
- 12.7 的禁止清單(streak、愛心、排行榜、推播督促、完成率/正確率、等級
  經驗值)一項都沒做。
- 12.8 音效沒做,依指示。

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
