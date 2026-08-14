import 'package:flutter/material.dart';

/// 視覺設計系統的顏色 token(SPEC.md 15.1,v10 定案)。
///
/// **唯一色彩來源。** 全專案不得再出現寫死的十六進位色碼或 `Colors.grey`
/// 之類的內建色,一律引用這裡的常數。除本檔案外,不准新增任何顏色。
class AppColors {
  AppColors._();

  /// 深墨色。主要文字、主要按鈕底色。
  static const primary = Color(0xFF22243A);

  /// 淡紫霧。次要面板、分隔、非活躍狀態。
  static const secondary = Color(0xFFE3E1EC);

  /// 鉻灰。輔助文字、圖示、進度條底槽。
  static const tertiary = Color(0xFFBCC0D2);

  /// 銀白。頁面背景。
  static const neutral = Color(0xFFF0EEF5);

  /// 卡片、選項按鈕底色。
  static const surface = Color(0xFFFFFFFF);

  /// 答對的選項——底色。
  static const correctBackground = Color(0xFFA9DED2);

  /// 答對的選項——字色。
  static const correctForeground = Color(0xFF1F5C4D);

  /// 答錯時使用者選的那個選項——底色。
  static const incorrectBackground = Color(0xFFF0C2DE);

  /// 答錯時使用者選的那個選項——字色。
  static const incorrectForeground = Color(0xFF7A2049);
}

/// 視覺設計系統的字級 token(SPEC.md 15.2,v10 定案)。
///
/// 七個具名 style,對應 SPEC 表格。**字重要跟 `pubspec.yaml` 裡實際打包的
/// TTF 檔對應**,不要用未打包的字重(Flutter 會退回系統字型)。
///
/// 這裡刻意不內建文字顏色——顏色由呼叫端用 `.copyWith(color: AppColors.x)`
/// 疊上去,字級 token 只管字型/大小/字重/字距。
class AppTextStyles {
  AppTextStyles._();

  // 【修 bug】Syne 是筆畫比較「滿」的展示型字體,不給 height 的話 Flutter
  // 用字型本身回報的行高算,會太緊,下伸部(g/y 的尾巴)在某些瀏覽器/縮放
  // 比例下會被裁掉(Shawn 實測回報:"upgrade" 的 g 尾巴被吃掉)。
  // 全部 7 個 token 都給明確的 height,不只是出事的 headline,避免同一個
  // 問題之後在別的字級重演。

  /// Syne 64 / 800。首頁轉盤數字。
  static const displayLarge = TextStyle(
    fontFamily: 'Syne',
    fontSize: 64,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Syne 34 / 800。「You know N words」、Library 標題。
  static const displayMedium = TextStyle(
    fontFamily: 'Syne',
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Syne 28 / 700。單字本身。
  static const headline = TextStyle(
    fontFamily: 'Syne',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Hanken Grotesk 15 / 400。定義、例句、選項。
  static const body = TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Hanken Grotesk 15 / 600。按鈕文字。
  static const bodyStrong = TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Hanken Grotesk 11 / 600,全大寫 + 寬字距。小標籤。
  static const label = TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    height: 1.4,
  );

  /// Hanken Grotesk 13 / 400。音標、輔助說明。
  static const caption = TextStyle(
    fontFamily: 'Hanken Grotesk',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

/// 主按鈕(膠囊狀,高度 52)與選項按鈕(圓角 14,高度 56)的共用圓角/高度
/// 數值(SPEC.md 15.3)。
class _AppShapes {
  _AppShapes._();

  static const primaryButtonHeight = 52.0;
  static const optionButtonHeight = 56.0;
  static const optionButtonRadius = 14.0;
  static const cardRadius = 20.0;
}

/// 整個 App 唯一的 [ThemeData]。SPEC.md 15.5:「各畫面改用
/// `Theme.of(context)` 或上述常數,移除所有寫死的色碼與 TextStyle」。
///
/// 這裡只設定共用的殼(背景色、AppBar、預設按鈕樣式)。**預設的
/// `ElevatedButton`/`OutlinedButton` 樣式是「選項按鈕」的樣子**(白底、
/// 圓角 14、高度 56),因為選項按鈕在畫面上出現的次數遠多於主按鈕;
/// 少數的主按鈕(首頁 START、完成畫面 HOME)在各自的 widget 呼叫端
/// 用 `style:` 參數疊成膠囊狀。
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.neutral,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    secondary: AppColors.secondary,
    onSecondary: AppColors.primary,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.primary,
    surface: AppColors.surface,
    onSurface: AppColors.primary,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.neutral,
    foregroundColor: AppColors.primary,
    elevation: 0,
    titleTextStyle: AppTextStyles.headline.copyWith(color: AppColors.primary),
  ),
  dividerColor: AppColors.tertiary,
  cardColor: AppColors.surface,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.tertiary,
      textStyle: AppTextStyles.bodyStrong,
      minimumSize: const Size.fromHeight(_AppShapes.optionButtonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_AppShapes.optionButtonRadius),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.bodyStrong,
      minimumSize: const Size.fromHeight(_AppShapes.optionButtonHeight),
      side: const BorderSide(color: AppColors.tertiary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_AppShapes.optionButtonRadius),
      ),
    ),
  ),
);

/// 主按鈕(首頁 START、完成畫面 HOME)專用的膠囊狀樣式。SPEC 15.3:
/// 「主按鈕為膠囊狀(圓角 = 高度的一半),高度 52」。
final ButtonStyle appPrimaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.surface,
  disabledBackgroundColor: AppColors.tertiary,
  disabledForegroundColor: AppColors.surface,
  textStyle: AppTextStyles.bodyStrong,
  minimumSize: const Size.fromHeight(_AppShapes.primaryButtonHeight),
  shape: const StadiumBorder(),
);

/// 卡片(認識卡、題目卡)共用的圓角(SPEC 15.3:卡片圓角 20)。
const double appCardRadius = _AppShapes.cardRadius;
