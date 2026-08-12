import 'package:flutter/material.dart';

/// 首頁背景裝飾:4 顆銀色金屬珍珠,緩慢上下飄浮(SPEC.md 第 14 節)。
///
/// **純裝飾,不可互動、不承載任何資訊。** 整個 widget 包在 [IgnorePointer]
/// 裡,不會攔截中央氣泡或按鈕的點擊。位置、大小、動畫參數全部照抄
/// SPEC 14.3 / 14.5 的表,不要自己調整。
class FloatingPearls extends StatefulWidget {
  const FloatingPearls({super.key});

  @override
  State<FloatingPearls> createState() => _FloatingPearlsState();
}

enum _HSide { left, right }

class _PearlSpec {
  /// 直徑(px)。
  final double diameter;
  final _HSide hSide;
  /// [hIsPx] 為 true 時是像素(可為負,代表故意讓珍珠被邊緣裁切);
  /// 為 false 時是佔畫面寬度的比例(0–1)。
  final double hValue;
  final bool hIsPx;
  /// 佔畫面可用高度的比例(0–1)。
  final double topPercent;
  /// 上下位移幅度(px),實際位移範圍是 ±amplitude。
  final double amplitude;
  /// 單趟(由中心到最高/最低點)週期。
  final Duration period;
  /// 起始相位(0–1),用來讓四顆珍珠的動畫節奏錯開,避免同步。
  final double initialPhase;

  const _PearlSpec({
    required this.diameter,
    required this.hSide,
    required this.hValue,
    required this.hIsPx,
    required this.topPercent,
    required this.amplitude,
    required this.period,
    required this.initialPhase,
  });
}

/// SPEC.md 14.3(位置與大小)+ 14.5(飄浮動畫)的四顆珍珠參數表。
const _pearlSpecs = [
  _PearlSpec(
    diameter: 200,
    hSide: _HSide.left,
    hValue: -70,
    hIsPx: true,
    topPercent: 0.12,
    amplitude: 10,
    period: Duration(seconds: 22),
    initialPhase: 0.0,
  ),
  _PearlSpec(
    diameter: 140,
    hSide: _HSide.right,
    hValue: -70,
    hIsPx: true,
    topPercent: 0.55,
    amplitude: 8,
    period: Duration(seconds: 18),
    initialPhase: 0.25,
  ),
  _PearlSpec(
    diameter: 90,
    hSide: _HSide.left,
    hValue: 0.08,
    hIsPx: false,
    topPercent: 0.74,
    amplitude: 6,
    period: Duration(seconds: 25),
    initialPhase: 0.5,
  ),
  _PearlSpec(
    diameter: 56,
    hSide: _HSide.right,
    hValue: 0.14,
    hIsPx: false,
    topPercent: 0.20,
    amplitude: 5,
    period: Duration(seconds: 15),
    initialPhase: 0.75,
  ),
];

class _FloatingPearlsState extends State<FloatingPearls>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  bool _startedAnimating = false;

  @override
  void initState() {
    super.initState();
    _controllers = _pearlSpecs
        .map(
          (spec) => AnimationController(vsync: this, duration: spec.period)
            ..value = spec.initialPhase,
        )
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedAnimating) return;
    _startedAnimating = true;
    if (!MediaQuery.of(context).disableAnimations) {
      for (final controller in _controllers) {
        controller.repeat(reverse: true);
      }
    }
    // disableAnimations == true 時完全不啟動 controller,珍珠停在
    // initialPhase 對應的靜止位置(見 SPEC 14.6)。
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: List.generate(_pearlSpecs.length, (i) {
              final spec = _pearlSpecs[i];
              final controller = _controllers[i];

              final baseTop = height * spec.topPercent;
              final left = spec.hSide == _HSide.left
                  ? (spec.hIsPx ? spec.hValue : width * spec.hValue)
                  : null;
              final right = spec.hSide == _HSide.right
                  ? (spec.hIsPx ? spec.hValue : width * spec.hValue)
                  : null;

              return AnimatedBuilder(
                animation: controller,
                // 把 Image.asset 當 child 快取,每一幀只重建 Positioned,
                // 不重建圖片本身(SPEC 14.6 效能要求)。
                child: Image.asset(
                  'assets/images/pearl.png',
                  width: spec.diameter,
                  height: spec.diameter,
                ),
                builder: (context, child) {
                  final eased = Curves.easeInOut.transform(controller.value);
                  final offset = (eased - 0.5) * 2 * spec.amplitude;
                  return Positioned(
                    top: baseTop + offset,
                    left: left,
                    right: right,
                    child: child!,
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }
}
