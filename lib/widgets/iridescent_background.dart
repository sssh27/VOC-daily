import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/app_theme.dart';

/// 虹彩流動背景(SPEC.md 第 16 節)。兩層材質以不同方向/速度移動,
/// 用 soft light 混合出流動感,不是單張圖平移。純裝飾,不可互動,
/// 包在 [IgnorePointer] 裡。
///
/// **C-4 的技術選擇:soft light 混合用 `CustomPainter` + `Canvas.saveLayer`
/// 實作,不是 `ShaderMask` 或 `ColorFiltered`。**
///
/// 理由:
/// - `ColorFiltered` 的 `ColorFilter.mode(color, blendMode)` 是拿「單一
///   顏色」跟 widget 的算繪結果混合,不是兩張圖之間混合,做不到這裡要的效果。
/// - `ShaderMask` 可以用 `ImageShader`(把 B 圖包成 shader)湊出兩張圖的
///   混合,但 `ShaderMask` 沒有獨立的「整體不透明度」通道——這裡同時需要
///   「B 層 softLight 混合」和「B 層維持 0.5 不透明度」兩件事,
///   `ShaderMask` 只能做前者;硬要在外面疊一層 `Opacity`,淡化的是
///   「A 層 + 混合後的 B 層」整體,連 A 層都會跟著變淡,不對。
/// - `Canvas.saveLayer(bounds, paint)` 的 `paint` 可以同時設
///   `blendMode` 和 `color` 的 alpha。Skia 在 `restore()` 把這個 layer
///   合成回底圖時,是先用 `blendMode` 算出「B 跟底圖混合後」的結果,
///   再用 `paint.color` 的 alpha 跟原本的底圖做線性插值
///   (`結果 = 底圖 * (1-alpha) + blend(底圖, B) * alpha`)——
///   這正好是 SPEC 要的「softLight 混合 + 0.5 不透明度」,而且省掉了
///   一層獨立的 `Opacity` widget。
class IridescentBackground extends StatefulWidget {
  const IridescentBackground({super.key});

  @override
  State<IridescentBackground> createState() => _IridescentBackgroundState();
}

class _IridescentBackgroundState extends State<IridescentBackground>
    with SingleTickerProviderStateMixin {
  // 只有這一個 controller,珍珠(floating_pearls.dart)與中央氣泡各自有
  // 自己的,不共用(SPEC 16.3)。是 repeat(),不是 repeat(reverse: true)——
  // 整個運動用三角函數構成,本身週期封閉,反向播放會出現折返感。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  ui.Image? _imageA;
  ui.Image? _imageB;
  bool _startedAnimating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage('assets/images/iridescent_a.webp').then((img) {
      if (!mounted) return;
      setState(() => _imageA = img);
    }));
    unawaited(_loadImage('assets/images/iridescent_b.webp').then((img) {
      if (!mounted) return;
      setState(() => _imageB = img);
    }));
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedAnimating) return;
    _startedAnimating = true;
    if (!MediaQuery.of(context).disableAnimations) {
      _controller.repeat();
    }
    // disableAnimations == true 時完全不啟動 controller,背景停在 t = 0
    // 的靜止畫面(SPEC 16.10)。
  }

  @override
  void dispose() {
    _controller.dispose();
    _imageA?.dispose();
    _imageB?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageA = _imageA;
    final imageB = _imageB;

    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 墊底,避免圖片載入前閃白(SPEC 16.3)。
              const ColoredBox(color: AppColors.neutral),
              if (imageA != null && imageB != null)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _IridescentPainter(
                        imageA: imageA,
                        imageB: imageB,
                        t: _controller.value,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 兩層材質的變換數學(SPEC 16.3 的表)。`t = controller.value`(0→1),
/// `a = 2π t`。
class _IridescentPainter extends CustomPainter {
  final ui.Image imageA;
  final ui.Image imageB;
  final double t;

  _IridescentPainter({
    required this.imageA,
    required this.imageB,
    required this.t,
  });

  // 過掃描 ×1.6 是必要的,不是保險——沒有這個,B 層旋轉時四個角會轉出
  // 畫面外,邊緣出現硬邊和空白。1.6 是實測後能同時容納 ±70px 位移與
  // 4° 旋轉的最小值,不要調小(SPEC 16.3)。
  static const _overscan = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final a = 2 * math.pi * t;

    // A 層:過掃描 ×1.6、額外縮放 1.0+0.05sin(a)、水平位移、垂直位移、無旋轉。
    final scaleA = _overscan * (1.0 + 0.05 * math.sin(a));
    final dxA = 70.0 * math.sin(a);
    final dyA = 110.0 * math.cos(0.7 * a);

    // B 層:過掃描 ×1.6、無額外縮放、水平位移、垂直位移、旋轉 4°*sin(0.5a)。
    const scaleB = _overscan;
    final dxB = -70.0 * math.cos(0.8 * a);
    final dyB = -110.0 * math.sin(0.6 * a);
    final rotB = 4.0 * math.pi / 180.0 * math.sin(0.5 * a);

    final layerPaint = Paint()..filterQuality = FilterQuality.medium;

    // A 層:正常畫,不混合、不透明。
    _drawCoverLayer(
      canvas,
      size,
      image: imageA,
      scale: scaleA,
      dx: dxA,
      dy: dyA,
      rotation: 0,
      paint: layerPaint,
    );

    // B 層:softLight 混合 + 0.5 不透明度,見檔案開頭的技術選擇說明。
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.softLight
        ..color = const Color.fromRGBO(0, 0, 0, 0.5),
    );
    _drawCoverLayer(
      canvas,
      size,
      image: imageB,
      scale: scaleB,
      dx: dxB,
      dy: dyB,
      rotation: rotB,
      paint: layerPaint,
    );
    canvas.restore();
  }

  /// 把 [image] 用 `BoxFit.cover` 的比例鋪滿 [size],中心對齊,
  /// 再疊上額外的縮放/位移/旋轉。**位移與縮放全部是 double,不取整**
  /// (SPEC 16.4 第 2 點——取整會變成階梯狀移動)。
  void _drawCoverLayer(
    Canvas canvas,
    Size size, {
    required ui.Image image,
    required double scale,
    required double dx,
    required double dy,
    required double rotation,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(size.width / 2 + dx, size.height / 2 + dy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final coverScale = math.max(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final totalScale = coverScale * scale;

    final destRect = Rect.fromCenter(
      center: Offset.zero,
      width: imageSize.width * totalScale,
      height: imageSize.height * totalScale,
    );
    final srcRect = Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);

    canvas.drawImageRect(image, srcRect, destRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IridescentPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.imageA != imageA ||
        oldDelegate.imageB != imageB;
  }
}
