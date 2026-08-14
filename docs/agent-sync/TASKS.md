# TASKS.md

> 國王餅(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。
>
> 上一輪(v10)的工作單已歸檔到 `archive/TASKS_v10.md`。

---

## 上一輪 review 結果

A(珍珠)、B(設計系統)、C(拿掉 AI 入口)、E(介面英文)都完成了。
D 你判斷「現況已經置中、不用改」是對的,那是我開錯單。

**但 Shawn 實機跑起來發現一個嚴重 bug,原因是我的工作單漏了檔案,不是你的錯。**
詳情看下面 A。

---

## 這一輪的順序與依賴

**A → B → C → D → E,照順序做,不要跳。**

- **A 是壞掉的畫面,必須最先修。** 沒修好之前做其他項目沒有意義
- B(寬度上限)會改變所有畫面的實際寬度,要在 C 之前做,
  否則你調背景時看到的比例是錯的
- C(背景)必須在 D(氣泡飄浮 / 圖示)之前,因為 D 要疊在 C 上面看對比
- E 是最後的整體驗收

---

## A. 修「學習畫面單字看不見」——最優先

### 現象

進入學習畫面,卡片變成深墨色底,單字和釋義完全看不到,
只看得到音標和中文例句。

### 原因(我的疏失)

上一輪 B 我列的檔案清單只寫了 `lib/screens/` 底下四個檔,**漏掉 `lib/widgets/`**。
所以這兩個檔完全沒被遷移到設計系統:

- `lib/widgets/intro_card.dart`
- `lib/widgets/question_card.dart`

它們還在用 `Theme.of(context).colorScheme.primaryContainer` 當卡片底色。
新的 `ColorScheme.light(primary: #22243A)` 讓 Material 3 推導出來的
`primaryContainer` 變成深色,而卡片內文字用預設的 `onSurface`(也是 `#22243A`),
**深字壓深底,字沒有不見,是被同色吃掉。**

### A-1 `lib/widgets/intro_card.dart`

外層 `Container` 的 `decoration`:

| 現在 | 改成 |
|---|---|
| `color: Theme.of(context).colorScheme.primaryContainer` | `color: AppColors.surface` |
| `borderRadius: BorderRadius.circular(16)` | `BorderRadius.circular(20)`(SPEC 15.3) |
| (無陰影) | 加 SPEC 15.3 的統一陰影(見下) |

統一陰影,全專案只用這一種:

```dart
BoxShadow(
  color: Color(0x0F22243A),   // #22243A 6%
  blurRadius: 24,
  offset: Offset(0, 8),
)
```

內部各段文字:

| 元素 | 現在 | 改成 |
|---|---|---|
| 單字 `word` | `textTheme.headlineSmall` | `AppTextStyles.headline.copyWith(color: AppColors.primary)` |
| 音標 `phonetic` | `bodyMedium` + `Colors.grey` | `AppTextStyles.caption.copyWith(color: AppColors.tertiary)` |
| 釋義 `meaning` | `textTheme.titleMedium` | `AppTextStyles.body.copyWith(color: AppColors.primary)` |
| 例句 `RichText` 的基底 style | `DefaultTextStyle.of(context).style` | `AppTextStyles.body.copyWith(color: AppColors.primary)` |
| 中文翻譯 `exampleZh` | `bodyMedium` + `Colors.grey[700]` | `AppTextStyles.caption.copyWith(color: AppColors.tertiary)` |

`Divider` 改成 `Divider(color: AppColors.secondary, height: 1, thickness: 1)`。

### A-2 `lib/widgets/question_card.dart`

同樣三處:`primaryContainer` → `AppColors.surface`、
單字 → `AppTextStyles.headline` + `AppColors.primary`、
音標 → `AppTextStyles.caption` + `AppColors.tertiary`。
圓角同樣改 20,同樣加上面那個陰影。

### A-3 順帶檢查

`lib/widgets/word_highlight.dart` 裡如果有寫死顏色或 `textTheme.*`,
一併照上表遷移。粗體標示的部分維持 `FontWeight.w700`,顏色用 `AppColors.primary`。

### A-4 做完自己驗一次(這一步不可以省)

在專案根目錄跑:

```bash
grep -rn "primaryContainer\|Colors\.grey\|Colors\.black\|Colors\.white\|textTheme\." lib --include=*.dart | grep -v "app_theme.dart" | grep -v "database.g.dart"
```

**預期結果是「完全沒有輸出」。** 有輸出就是還沒改乾淨。

**把這條指令的實際輸出原封不動貼進 `PROGRESS.md`。**
上一輪就是少了這一步才漏掉 `lib/widgets/`。

---

## B. 網頁版寬度上限

**規格:SPEC 16.9。**

現在 web 版沒有最大寬度,按鈕會整條拉滿貼到瀏覽器邊緣。

### 要做的

`lib/main.dart` 的 `MaterialApp` 加上 `builder`:

```dart
builder: (context, child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 430),
    child: child,
  ),
),
```

- `child` 可能為 null,要處理(`child ?? const SizedBox.shrink()`)
- 430 是設計稿基準寬度,不要改成別的數字
- 兩側超出的區域會露出 `scaffoldBackgroundColor`,也就是 `AppColors.neutral`,
  這是預期行為

### 絕對不要

- **不要在每個畫面各包一次。** 全域一次就好
- 不要用 `MediaQuery` 判斷平台再決定要不要包。手機上畫面本來就小於
  430,包了也不影響

---

## C. 虹彩流動背景

**完整規格:SPEC 第 16 節,尤其 16.1、16.3、16.4、16.5。**
下面是逐步實作指引,但**數值一律以 SPEC 的表為準**。

材質我已經產生好、`pubspec.yaml` 也註冊完了。**你不用碰素材。**

```
assets/images/iridescent_a.webp    1400×2000   37KB
assets/images/iridescent_b.webp    1400×2000   32KB
```

### C-1 新增 `lib/widgets/iridescent_background.dart`

一個 `StatefulWidget`,名字叫 `IridescentBackground`,沒有必填參數。

**結構由外到內:**

```
IgnorePointer
└── RepaintBoundary
    └── ClipRect
        └── Stack (fit: StackFit.expand)
            ├── Container(color: AppColors.neutral)     ← 墊底,防止載入前閃白
            ├── A 層  (AnimatedBuilder → Transform)
            └── B 層  (Opacity 0.5 + BlendMode.softLight)
```

### C-2 動畫控制器

```dart
late final AnimationController _c = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 60),
);
```

在 `didChangeDependencies` 裡,若 `!MediaQuery.of(context).disableAnimations`
才 `_c.repeat()`。

- **是 `repeat()`,不是 `repeat(reverse: true)`。**
  整個運動由 `sin` / `cos` 構成,本身就週期封閉,反向播放會出現折返感
- 只有這一個 controller。珍珠和中央氣泡各自有自己的,**不要共用**
- `dispose()` 要釋放

### C-3 兩層的變換

設 `t = _c.value`,`a = 2 * math.pi * t`:

```dart
// A 層
final scaleA = 1.6 * (1.0 + 0.05 * math.sin(a));
final dxA    = 70.0  * math.sin(a);
final dyA    = 110.0 * math.cos(0.7 * a);

// B 層
const scaleB = 1.6;
final dxB    = -70.0  * math.cos(0.8 * a);
final dyB    = -110.0 * math.sin(0.6 * a);
final rotB   = 4.0 * math.pi / 180.0 * math.sin(0.5 * a);   // 4 度,注意是弧度
```

每一層的組法(順序不能顛倒):

```dart
Transform.translate(
  offset: Offset(dx, dy),
  child: Transform.rotate(          // A 層沒有旋轉,可省略這層
    angle: rot,
    child: Transform.scale(
      scale: scale,
      child: child,                 // ← AnimatedBuilder 的 child
    ),
  ),
)
```

`child` 是:

```dart
Image.asset(
  'assets/images/iridescent_a.webp',
  fit: BoxFit.cover,
  filterQuality: FilterQuality.medium,
)
```

#### 過掃描 ×1.6 是必要的,不是保險

我第一版沒加,結果 B 層旋轉時四個角會轉出畫面外,
邊緣出現硬邊和空白——那正是 Shawn 說的「粗糙」。
1.6 是實測後能同時容納 ±70px 位移與 4° 旋轉的最小值,**再小會露邊**。

驗收第 3 點就是在檢查這個。

### C-4 混合

B 層外面包:

```dart
Opacity(
  opacity: 0.5,
  child: ShaderMask(...)   // 不需要 ShaderMask,見下
)
```

soft light 的做法:用 `BlendMode.softLight` 的 `ColorFiltered` 做不到
(那是拿單色去混),要用 **`Stack` + `BlendMode`**:

```dart
Opacity(
  opacity: 0.5,
  child: ColorFiltered(          // ← 不要這樣做
    ...
  ),
)
```

**正確做法是把 B 層放進一個 `BlendMask`:** Flutter 的做法是在
`Stack` 裡對 B 層用 `Positioned.fill` 包一個
`Opacity(opacity: 0.5, child: ...)`,再讓整個 `Stack` 的
B 層 child 外面套:

```dart
// B 層最外層
Positioned.fill(
  child: Opacity(
    opacity: 0.5,
    child: _blendSoftLight(bLayerWidget),
  ),
)
```

其中 `_blendSoftLight` 用 `ShaderMask` 做不到,要用
**`BackdropFilter` 也做不到**。正確的 API 是給 `Stack` 裡的那一層包一個
自訂的 `CustomPaint` 或直接用 `ImageFiltered`——

**這裡我不確定 Flutter 最乾淨的寫法是哪一個,所以:
請你先查一下 `BlendMode.softLight` 在 Flutter widget 樹裡最簡潔的套用方式
(候選:`ColorFiltered`、`ShaderMask`、`CustomPainter` 直接
`canvas.saveLayer(paint..blendMode = BlendMode.softLight)`),
選一個實作,並在 `PROGRESS.md` 說明你選了哪個、為什麼。**

我的傾向是 `CustomPainter` + `saveLayer`,因為那是唯一能精確控制
兩個 image 之間 blend mode 的方式,而且可以順便省掉一層 `Opacity`
(直接把 `paint.color = Color.fromRGBO(0,0,0,0.5)` 當 alpha)。
但你實作起來如果發現有更簡單的做法,採用你的,只要說明理由。

**不用做的事:執行時不要再調對比。** 對比已經預先烘進素材,
我實測過:不套後製對比,畫面標準差 6.90,套了是 7.68,幾乎一樣,
但少一道每幀全畫面運算,而且不會把 8-bit 色階斷帶一起放大。

### C-5 避免顆粒感與卡頓(SPEC 16.4,逐條照做)

1. 兩層的 `Image.asset` 都要 `filterQuality: FilterQuality.medium`。
   預設的 `low` 在縮放旋轉時會有閃爍鋸齒。**不要用 `high`**,
   web 上成本明顯偏高而看不出差別
2. 位移量一律 `double`,**絕對不要 `round()` / `toInt()`**。
   60 秒一圈、位移只有 ±70px,每幀位移不到 0.02px,
   一取整就會變成「每隔幾秒跳一格」的階梯狀移動
3. 整個背景包 `RepaintBoundary`,否則每幀會連帶重繪首頁其他內容
4. `AnimatedBuilder` 的 `child` 一定要用,`builder` 裡不要呼叫 `Image.asset`
5. **不要在執行時套 `ImageFilter.blur` 或 `BackdropFilter`**,
   模糊已經烘進素材,執行時全畫面模糊在 web 上非常貴
6. **不要自己加雜訊或 dither**,素材裡已經有 σ≈0.0016 的細顆粒

### C-6 接到首頁

`home_screen.dart` 目前的 `Stack` 改成三層,順序照 SPEC 16.5:

```dart
body: Stack(
  children: [
    const IridescentBackground(),   // 新增,最底層
    const FloatingPearls(),         // 既有
    Center(...),                    // 既有內容
  ],
),
```

`FloatingPearls` 目前有自己的背景嗎?沒有的話不用動它。

### C-7 絕對不要

- **不要用 `FragmentProgram` 或任何 shader。**
  Flutter Web 的 CanvasKit 不支援(flutter/flutter#114121 仍開著),
  本專案目標平台就是 Web,寫了不會動
- **不要引入任何第三方套件**
- **不要調材質的顏色、亮度、飽和度**
- **不要因為「看起來好像沒在動」就把 60 秒改快。**
  慢是刻意的,見 SPEC 16.11

---

## D. 拉霸圖示、金屬圖示、中央氣泡飄浮

### D-1 拿掉「SPIN」文字(SPEC 16.7)

**拉霸圓圈裡不要出現任何文字。**

`home_screen.dart` 的 `_buildCircleContent`,未轉狀態目前是:

```dart
Column(
  children: [
    Text('🎰', style: TextStyle(fontSize: 40)),
    SizedBox(height: 8),
    Text('SPIN'),
  ],
)
```

改成**只有一個金屬骰子圖示**,尺寸 56,置中,`Column` 和 `SizedBox` 都不要了。

轉動中、轉完的狀態維持現狀,不要動。

#### 可觸碰性補償

拿掉文字後少了「這裡可以點」的暗示,所以未轉狀態的圖示加一個
極輕微的呼吸動畫:

- 縮放 `1.0 ↔ 1.04`
- 單趟 **2.4 秒**
- `Curves.easeInOut`
- `repeat(reverse: true)`
- **只有未轉狀態有**,轉完之後不要

### D-2 金屬圖示(SPEC 16.8)

新增一個小 widget,建議放 `lib/widgets/chrome_icon.dart`:

```dart
class ChromeIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const ChromeIcon(this.icon, {super.key, required this.size});

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE2E5EE),
      Color(0xFF969BAF),
      Color(0xFF3E4356),
      Color(0xFF22243A),
      Color(0xFF787F92),
    ],
    stops: [0.00, 0.30, 0.60, 0.85, 1.00],
  );

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcATop,          // ← 不是 srcIn
    shaderCallback: (r) => _gradient.createShader(r),
    child: Icon(icon, size: size, color: Colors.white),
  );
}
```

用它替換兩處 emoji:

| 位置 | 圖示 | 尺寸 |
|---|---|---|
| `home_screen.dart` 拉霸未轉 | `Icons.casino_outlined` | 56 |
| `review_screen.dart` 完成畫面里程碑 | `Icons.auto_awesome` | 40 |

里程碑那處外面既有的 `TweenAnimationBuilder` 放大動畫保留,
只把 `Text('🎉')` 換成 `ChromeIcon`。

#### 為什麼圖示的色階比珍珠深

我把三組色階實際畫在虹彩背景上比對過:沿用珍珠那組
(最深只到 `#6E7484`)在淺背景上幾乎看不見。
小尺寸圖示需要比大面積物件更強的明暗差才讀得出形狀。

**這兩組色階不要互換、不要統一。**
珍珠用第 14 節的 PNG 素材,圖示用上面這組漸層。

#### 注意

- `blendMode` 用 `BlendMode.srcATop`。用 `srcIn` 會把圖示的透明區域一起填掉
- 底下的 `Icon` 顏色要給 `Colors.white`(會被漸層蓋掉,但不給的話
  某些情況會拿到透明)。**這是 `app_theme.dart` 以外唯一允許出現
  `Colors.white` 的地方**,請在該行加註解說明原因,免得下次 grep 檢查誤判

### D-3 中央氣泡飄浮(SPEC 16.6)

- 位移 **±6px**,單趟週期 **19 秒**,`Curves.easeInOut`,`repeat(reverse: true)`
- 19 秒刻意跟四顆珍珠的 22/18/25/15 都不同,**不要改成一樣的**
- **只做垂直位移。** 不旋轉、不縮放、不改透明度
- **拉霸轉動中(`_rolling == true`)時暫停飄浮**,不然兩個動畫會打架
  (實作:`_rolling` 時 `controller.stop()`,結束後 `repeat(reverse: true)`)

---

## E. 整體驗收

照 SPEC 16.12 的十二點逐項確認,結果寫進 `PROGRESS.md`。

**你沒有 Flutter / 瀏覽器環境,所以請明確區分:**

- 哪幾點你從程式碼結構可以確認
- 哪幾點必須 Shawn 實機看(尤其第 2、3、4、7 點,那些是動態與視覺品質)

不要把「程式碼寫成這樣所以應該沒問題」寫成已驗證。

---

## 這一輪不要做的事

- 不要動 Study 流程的互動邏輯、選項產生方式、計分方式
- 不要動排程演算法、拉霸邏輯、資料庫 schema
- 不要動 `assets/decks/*.json`(牌組名稱還是中文是已知的,下一輪處理)
- 不要動 `lib/services/ai_service.dart` 與 `lib/screens/generate_screen.dart`
- 不要做 Onboarding 和 Settings,那兩個畫面還沒開始
- 不要動 `lib/logic/scheduler.dart` 與 `test/scheduler_test.dart`(永久規則)

---

## 做完之後

**停下來等 review。**

`PROGRESS.md` 請寫清楚這五件事:

1. A ~ D 每一項的完成狀態
2. **A-4 那條 grep 指令的實際輸出原文**
3. C-4 你選了哪種方式做 soft light 混合,以及為什麼
4. `flutter test` 的結果
5. SPEC 16.12 十二點,逐點標明「程式碼已確認」或「需 Shawn 實機確認」
