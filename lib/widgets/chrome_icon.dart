import 'package:flutter/material.dart';

/// 銀色金屬圖示(SPEC.md 16.8)。Material 內建圖示 + `ShaderMask` 疊銀色
/// 漸層,取代跟整體調性衝突的彩色 emoji(🎰、🎉)。不新增圖片素材、
/// 不引入套件。
///
/// **這組色階刻意比珍珠(第 14 節素材)深**,小尺寸圖示需要比大面積
/// 物件更強的明暗差才讀得出形狀。兩組色階不要互換、不要統一。
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
  Widget build(BuildContext context) {
    return ShaderMask(
      // srcATop,不是 srcIn——srcIn 會把圖示的透明區域一起填掉。
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => _gradient.createShader(rect),
      // 這是 app_theme.dart 以外唯一允許出現 Colors.white 的地方:
      // ShaderMask 需要一個不透明的底色來源才能被漸層完整蓋掉,
      // 不給的話某些情況會拿到透明。
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
