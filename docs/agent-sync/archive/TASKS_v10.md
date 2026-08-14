# TASKS.md

> 國王餅(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。
>
> 上一輪的工作單已歸檔到 `archive/TASKS_v9.md`。

---

## 這一輪是什麼

**視覺改版第一批。** 範圍是:背景裝飾、設計系統(顏色/字型/圓角)、
以及三處版面修正。

因為要建立設計系統,**這一輪你會大量改動顏色、字級、圓角** ——
這是被授權的,但**只能照 `docs/SPEC.md` 第 15 節的 token 表照抄,
一個色碼、一個字級都不准自己發明**。

**不在這一輪範圍內、不准動的:**

- 排程演算法、拉霸邏輯、資料庫 schema
- 卡片內容(`assets/decks/*.json` 一個字都不要改)
- Study 流程的互動邏輯、選項產生方式、計分方式
- Onboarding 與 Settings 畫面(目前根本還沒實作,這輪不做)
- `lib/services/ai_service.dart`(整個檔案連註解一起保留)

---

## 動工前先做兩件事

**1. 看設計稿。** `docs/design/` 有 9 張 Stitch 產出、Shawn 已確認的畫面圖。
用 Read 工具實際打開來看,不要只讀檔名猜內容。這輪會動到的:

- `01-home-ready-to-start.png`
- `02-home-not-yet-spun.png`
- `05-study-complete.png`
- `06-library.png`
- `09-design-system.png`(色票與字型總覽)

**2. 讀 `docs/SPEC.md` 第 14 節與第 15 節。** 那是規格。

**設計稿與 SPEC 衝突時,一律以 SPEC 為準。** 已知不一致寫在
`docs/design/README.md`。設計稿只是給你看「大概長怎樣」,
精確數值全部來自 SPEC。

---

## 執行順序

**照 A → B → C → D → E 的順序做,不要跳。**

- B 會大幅改動所有畫面的樣式,先做完 A 再做 B,不然珍珠會被 B 的改動蓋掉
- E(改英文)放最後,因為 B/C/D 會搬動這些字串的位置,先翻會白做兩次

> **第二輪更新(2026-08-12):** A 已完成、D 確認不用做。
> **B 仍卡在缺字型檔,C 和 E 現在可以做了** ——
> 順序改成 **C → E**,B 等 Shawn 把字型放進 `assets/fonts/` 再回頭補。
> C 只動一個按鈕、E 只換字串,兩者都不碰樣式,不會跟之後的 B 打架。

---

## A. 首頁背景金屬珍珠 + 飄浮動畫

**完整規格:`docs/SPEC.md` 第 14 節。** 那裡有素材路徑、四顆珍珠的
尺寸/位置表、動畫參數表、圖層順序、效能要求、驗收條件。

素材我已經處理好、`pubspec.yaml` 也註冊完了。**你不用碰素材,
也不要重新產生或裁切它。**

### 檔案

- 新增:`lib/widgets/floating_pearls.dart`
- 修改:`lib/screens/home_screen.dart`

### 要做的

1. `floating_pearls.dart` 匯出一個 `FloatingPearls` widget
   - 內部自己管四個 `AnimationController`
   - 整個 widget 外層包 `IgnorePointer`
   - 用 `Stack` + `Positioned` 擺四顆,位置照 SPEC 14.3 的表
2. 在 `home_screen.dart` 的 `Scaffold.body` 外面包一層 `Stack`,
   `FloatingPearls` 放第一個 child(最底層),原本的 `Center(...)` 放第二個
3. 四顆的位移曲線用 `Curves.easeInOut`,週期照 SPEC 14.5 的表
   - **起始相位一定要錯開**,四個 controller 用不同的初始 `value`
     (例如 0.0 / 0.25 / 0.5 / 0.75),否則四顆會整齊同步,看起來很假
4. `AnimatedBuilder` 的 `child` 參數要用上,把 `Image.asset` 傳進去快取,
   避免每一幀重建
5. `dispose()` 釋放全部四個 controller

### 絕對不要

- **不要改中央那顆主圓圈的大小、位置或樣式。** 這一輪它完全不動。
- **不要給珍珠加 `BoxShadow`、`ColorFiltered`、`Opacity` 或任何濾鏡。**
  PNG 素材本身就是最終樣子。之前 Stitch 一直自作主張在球外面加灰色外圈,
  我們花了很多輪才修掉,不要重蹈覆轍。
- **不要用 `Image.asset('assets/images/2.0x/pearl.png')`。**
  只寫 `assets/images/pearl.png`,Flutter 會自動依螢幕密度挑 2x/3x。

### 驗收

照 SPEC 14.7 的八點逐項確認,結果寫進 `PROGRESS.md`。
第 4 點(四顆節奏不同步)**請實際跑起來用眼睛看**,不要只看程式碼推斷。

---

## B. 建立設計系統(顏色 / 字型 / 圓角)

**完整規格:`docs/SPEC.md` 第 15 節。**

### 前置條件:字型檔

`assets/fonts/` 要有 Syne 與 Hanken Grotesk 的 **static TTF** 檔。
Shawn 會從 Google Fonts 下載放進去。

**陷阱提醒:** Google Fonts 下載下來的 zip 裡通常同時有
`Syne-VariableFont_wght.ttf` 和一個 `static/` 資料夾。
**Flutter 請用 `static/` 底下的固定字重檔**(例如 `Syne-Bold.ttf`、
`Syne-ExtraBold.ttf`),不要用 VariableFont 版本,那個在 Flutter 上
字重會失效、全部變同一種粗細。

如果你開工時字型檔還不在,**只有 B 要等,A / C / D / E 都不受影響照做**,
並在 `PROGRESS.md` 明確寫「B 卡在缺字型檔」。

> **更正(v10 第二輪):** 上一版這裡誤寫成「B/C 等檔案到齊再做」,
> 把 C 也綁進字型的前置條件,那是我寫錯了。C 只是拿掉一個按鈕,
> E 只是換字串,兩者都跟字型無關。已解除。

### 檔案

- 新增:`lib/theme/app_theme.dart`
- 修改:`pubspec.yaml`、`lib/main.dart`,以及四個 screen 檔

### 要做的

1. `app_theme.dart` 定義三樣東西:
   - `AppColors`:照 SPEC 15.1 的表,五個基本色 + 兩組狀態色
   - `AppTextStyles`:照 SPEC 15.2 的字級表,七個具名 style
   - `appTheme`:一個 `ThemeData`,把上面兩者接上去
2. `pubspec.yaml` 的 `fonts:` 區塊註冊兩套字型,`weight` 要跟實際檔案對應
3. `main.dart` 把 `theme:` 換成 `appTheme`
4. 四個 screen(`home_screen`、`review_screen`、`decks_screen`、
   `generate_screen`)改成引用 `AppColors` / `AppTextStyles`

### 這一步是「機械式替換」,不是重新設計

**你要做的是把寫死的數值換成 token,不是重排版面。**

具體來說:
- 看到 `Colors.grey[700]` → 換成 `AppColors.tertiary`
- 看到 `TextStyle(fontSize: 40)` → 換成對應的 `AppTextStyles.displayLarge`
- 看到 `Theme.of(context).textTheme.headlineSmall` → 換成具名 style

**不要**趁機調整 `SizedBox` 的高度、不要改 `Column` 的排列、
不要新增或刪除任何 widget。版面的調整只做 D 那一項,其他都維持原樣。

### 絕對不要

- **不要用 `google_fonts` 套件。** 字型走本地 asset,理由是離線(郵輪無網路)
  一定要顯示得出來,而且不引入新套件。
- **不要自己新增 SPEC 沒列的顏色。** 需要新色階就停下來寫 `QUESTIONS.md`。
- **不要動 `assets/decks/*.json`。**

---

## C. 拿掉 Library 的 AI 生成入口

### 背景更正

我先前根據設計稿判斷 Library 要改的地方,實際讀 code 之後發現有兩項是我誤判:

- 「MODULE 01/02/03」標籤 → **程式碼裡根本沒有**,那是 Stitch 自己編的,不用處理
- 牌組名稱寫死 → **本來就是動態的**(`repo.allDecks()`),不用處理

所以 C 只剩一件事。

### 要做的

`lib/screens/decks_screen.dart`:拿掉「+ AI 生成新單字」按鈕
(約在第 110 行)以及它的 `_goToGenerate` 方法和 `generate_screen.dart` 的 import。

### 注意

- **`lib/services/ai_service.dart` 和 `lib/screens/generate_screen.dart`
  兩個檔案完整保留,一個字都不要刪。** 只是把 Library 上的入口拿掉,
  之後做完後端代理還要接回來。`ai_service.dart` 裡的警告註解尤其不准刪。
- 牌組的進度條與百分比 **保留**。這是 Shawn 裁定的例外,見 CLAUDE.md
  「例外二」。**這個例外只適用 Library,首頁和學習流程仍然完全禁止。**

---

## D. 學習完成畫面改為垂直置中 —— ✅ 已結案,不用做

**這一項是我開錯的,你的判斷是對的。**

我當時是看 Stitch 設計稿 `05-study-complete.png` 上面靠上對齊、下半部一大片
空白,就直接當成程式碼的問題開單,而且憑印象編了一個 `_buildDoneMode` 的
函式名稱,實際上不存在。

真實情況:`review_screen.dart` 的完成畫面是
`body: Center(child: _buildCompletionContent(...))` 加上
`Column(mainAxisSize: min)`,**本來就是垂直置中的**。要修的是設計稿,不是程式碼。

你沒有為了交差硬改一個沒壞的東西,而是回報「找不到這個函式、現況已經符合」,
這是對的做法。**以後遇到 TASKS 描述跟程式碼對不上,都照這樣處理。**

---

## E. 介面文字改英文

Shawn 決定介面要全英文。**範圍已經確認過了,只改「介面」,不改「內容」。**

### 界線:哪些改、哪些不改

| 改 | 不改 |
|---|---|
| 按鈕、標題、提示、狀態文字 | 卡片的 `meaning`(中文釋義)|
| 完成畫面的文案池 | 卡片的 `exampleZh`(中文例句翻譯)|
| | `assets/decks/*.json` 任何欄位 |
| | 程式碼註解、`QUESTIONS.md`、`PROGRESS.md` |
| | `throw` 出來的錯誤訊息(內部用,不露給使用者)|

四選一的選項仍然是中文釋義,這是刻意的,**不要自作主張翻成英文**。
Shawn 明確裁定:英→中的方向難度剛好,改成英英會拉高錯誤率。

### 完整字串對照表

**照抄,不要自己改寫措辭。** 大小寫也照抄(全大寫的就是全大寫)。

> 行號是我寫這份文件時的狀態,**A 已經改過 `home_screen.dart`,行號會有偏移。
> 一律以「原文」欄的字串內容去搜尋定位,不要照行號硬跳。**

`lib/screens/home_screen.dart`

| 行 | 原文 | 改成 |
|---|---|---|
| 112 / 124 | `VOC-daily` | `VOC · DAILY` |
| 157 | `你認識了 $n 個字` | `You know $n words` |
| 166 | `開始` | `START` |
| 171 | `今天沒有要學的了` | `Nothing to study today` |
| 199 | `轉一下` | `SPIN` |
| 205 | `🎉 今天放假,\n沒有新字` | `DAY OFF\nNo new words` |
| 212 | `今天先把\n之前的做完就好` | `Just finish\nwhat you have` |
| 218 | `今日新字:\n$n 個` | `NEW TODAY\n$n` |

`lib/screens/review_screen.dart`

| 行 | 原文 | 改成 |
|---|---|---|
| 347/354/366/372 | `學習` | `STUDY` |
| 412 | `你認識了 $n 個字` | `You know $n words` |
| 418 | `單字庫快用完了,去生成新的吧` | `Your word bank is running low` |
| 428 | `回首頁` | `HOME` |
| 452 / 484 | `下一個` | `NEXT` |
| 459 | `我會了` | `I KNOW THIS` |
| 525 | `忘了` | `I FORGOT` |

`lib/screens/decks_screen.dart`

| 行 | 原文 | 改成 |
|---|---|---|
| 66 | `單字庫` | `LIBRARY` |
| 77 | `你認識了 $n 個字` | `You know $n words` |
| 94 | `已學 $x / $y 字` | `$x / $y learned` |

`lib/logic/completion_messages.dart` — 整個文案池換掉:

```dart
const completionMessagePool = [
  'Done for today',
  "That's a wrap",
  'All finished',
  "Today's batch is done",
  'All done, go do something else',
];

String milestoneMessage(int milestone) => "That's $milestone words";
```

### 順帶要改的測試

`test/completion_messages_test.dart` 最後一個測試的 `bannedWords` 目前只有中文,
文案改英文後那個檢查形同虛設。把清單改成:

```dart
const bannedWords = [
  '正確率', '花費', '分鐘', '秒', '%',
  'accuracy', 'streak', 'score', 'minutes', 'seconds', 'correct',
];
```

並確認比對是**大小寫不敏感**的(把 message 轉小寫再比)。

### 不用動的檔案

`lib/screens/generate_screen.dart` 在 C 之後已經沒有入口進得去,
這輪**不用翻譯它**,維持中文即可。

### 驗收

1. 全 App 走一遍(首頁三種狀態 → 學習 → 完成 → Library),
   **介面上看不到任何中文**,除了四選一的選項和卡片釋義
2. 全專案搜尋「複習」和「review」,UI 字串裡一個都沒有
   (`review_screen.dart` 這個**檔名**可以留,那是程式碼不是介面)
3. `flutter test` 全綠

---

## 做完之後

**停下來等 review。** 不要自行往下做 Onboarding、Settings、
或 Study 流程的視覺改版,那些規格還沒定案,提前做會白做。

`PROGRESS.md` 請寫清楚:每一項的完成狀態、`flutter test` 結果、
以及 A 的驗收八點你實際觀察到什麼。
