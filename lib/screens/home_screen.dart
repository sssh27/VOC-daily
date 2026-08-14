import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/daily_roll.dart' as roll;
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome_icon.dart';
import '../widgets/floating_pearls.dart';
import '../widgets/iridescent_background.dart';
import 'decks_screen.dart';
import 'review_screen.dart';

/// 首頁(SPEC.md 6.1,v4)。整個 App 的主畫面,極簡:一個轉盤 + 一個
/// 「開始」按鈕 + 右上角 ☰ 通往單字庫。
///
/// 拉霸就地播放動畫(不再跳到獨立畫面,見 6.2 廢止說明)。
///
/// 嚴格禁止顯示:積壓數字、連續天數、完成率、任何評比,以及「複習」兩個字。
/// 【v7】累計字數不在禁止之列,要顯示(見 SPEC.md 12.2)。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  // 【v7/12.6】拉霸動畫改成漸慢定格:間隔從 _minTickInterval 開始,隨著
  // 時間經過線性拉長到 _maxTickInterval,總時長仍落在 1.5–2 秒。
  static const _rollTotalDuration = Duration(milliseconds: 1800);
  static const _minTickInterval = Duration(milliseconds: 50);
  static const _maxTickInterval = Duration(milliseconds: 300);
  static const _flashCandidates = [0, 3, 4, 5, 6];

  bool _loading = true;
  DailyRoll? _todaysRoll;
  int _studyQueueCount = 0;
  int _totalIntroduced = 0;

  bool _rolling = false;
  int _displayNumber = 0;
  final _flashRandom = Random();

  // 【v11/16.7】拉霸圖示的呼吸動畫,只有「未轉」狀態有(見 _syncAnimations)。
  late final AnimationController _breatheController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // 【v11/16.6】中央主氣泡的飄浮動畫,拉霸轉動中暫停。
  late final AnimationController _bubbleController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 19),
  );

  bool _reducedMotion = false;
  bool _animationsReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsReady) return;
    _animationsReady = true;
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    _syncAnimations();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  /// 依目前狀態(轉盤是否轉動中、是否已經轉過、是否關閉動態效果)決定
  /// 拉霸圖示的呼吸動畫、中央氣泡的飄浮動畫該不該跑(SPEC 16.6/16.7/16.10)。
  void _syncAnimations() {
    if (!_animationsReady) return;

    if (_reducedMotion) {
      _breatheController.stop();
      _bubbleController.stop();
      return;
    }

    // 拉霸圖示呼吸:只有「未轉」狀態有,轉動中或轉完都不要。
    final rolledToday = _todaysRoll != null;
    if (!rolledToday && !_rolling) {
      if (!_breatheController.isAnimating) {
        _breatheController.repeat(reverse: true);
      }
    } else {
      _breatheController.stop();
    }

    // 中央氣泡:拉霸轉動中暫停,其餘時間都飄浮。
    if (_rolling) {
      _bubbleController.stop();
    } else if (!_bubbleController.isAnimating) {
      _bubbleController.repeat(reverse: true);
    }
  }

  Future<void> _load() async {
    final repo = ref.read(cardRepositoryProvider);
    final todaysRoll = await repo.todaysRoll();
    final queue = await repo.studyQueue();
    final introduced = await repo.introducedCount();
    if (!mounted) return;
    setState(() {
      _todaysRoll = todaysRoll;
      _studyQueueCount = queue.length;
      _totalIntroduced = introduced;
      _loading = false;
    });
    _syncAnimations();
  }

  Future<void> _startRoll() async {
    if (_rolling || _todaysRoll != null) return;
    setState(() => _rolling = true);
    _syncAnimations();

    final repo = ref.read(cardRepositoryProvider);
    final stopwatch = Stopwatch()..start();
    final totalMs = _rollTotalDuration.inMilliseconds;
    final minMs = _minTickInterval.inMilliseconds;
    final maxMs = _maxTickInterval.inMilliseconds;

    while (stopwatch.elapsed < _rollTotalDuration) {
      final progress = stopwatch.elapsed.inMilliseconds / totalMs;
      final delayMs = minMs + (maxMs - minMs) * progress;
      await Future.delayed(Duration(milliseconds: delayMs.round()));
      if (!mounted) return;
      setState(() {
        _displayNumber =
            _flashCandidates[_flashRandom.nextInt(_flashCandidates.length)];
      });
    }

    final backlog = await repo.backlogCount();
    final result = roll.rollNewCardQuota(backlog);
    await repo.recordRoll(quota: result.quota, wasCapped: result.wasCapped);
    if (result.quota > 0) {
      await repo.introduceNewCards(result.quota);
    }
    if (!mounted) return;
    setState(() => _rolling = false);
    _syncAnimations();
    await _load();
  }

  Future<void> _goStudy() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );
    _load();
  }

  void _goDecks() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DecksScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('VOC · DAILY')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final roll = _todaysRoll;
    final rolledToday = roll != null;
    final isJackpot = rolledToday && roll.quota == 0 && !roll.wasCapped;
    final wasCappedZero = rolledToday && roll.quota == 0 && roll.wasCapped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOC · DAILY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _goDecks,
          ),
        ],
      ),
      body: Stack(
        children: [
          const IridescentBackground(),
          const FloatingPearls(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _bubbleController,
                  child: GestureDetector(
                    onTap: rolledToday ? null : _startRoll,
                    child: Container(
                      width: 160,
                      height: 160,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: _buildCircleContent(
                        rolledToday: rolledToday,
                        isJackpot: isJackpot,
                        wasCappedZero: wasCappedZero,
                        roll: roll,
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    // SPEC 16.6:中央主氣泡飄浮,±6px,只做垂直位移。
                    final eased =
                        Curves.easeInOut.transform(_bubbleController.value);
                    final offset = (eased - 0.5) * 2 * 6.0;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'You know $_totalIntroduced words',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: appPrimaryButtonStyle,
                  onPressed: _studyQueueCount > 0 ? _goStudy : null,
                  child: const Text('START'),
                ),
                if (rolledToday && _studyQueueCount == 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Nothing to study today',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.tertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleContent({
    required bool rolledToday,
    required bool isJackpot,
    required bool wasCappedZero,
    required DailyRoll? roll,
  }) {
    if (_rolling) {
      return Text(
        '$_displayNumber',
        style: AppTextStyles.displayLarge.copyWith(color: AppColors.primary),
      );
    }
    if (!rolledToday) {
      // SPEC 16.7:圓圈裡不要有任何文字,只有一個金屬骰子圖示,
      // 未轉狀態加極輕微的呼吸動畫補償可觸碰性。
      return AnimatedBuilder(
        animation: _breatheController,
        child: const ChromeIcon(Icons.casino_outlined, size: 56),
        builder: (context, child) {
          final eased = Curves.easeInOut.transform(_breatheController.value);
          final scale = 1.0 + 0.04 * eased;
          return Transform.scale(scale: scale, child: child);
        },
      );
    }
    if (isJackpot) {
      return Text(
        'DAY OFF\nNo new words',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
      );
    }
    if (wasCappedZero) {
      return Text(
        'Just finish\nwhat you have',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
      );
    }
    return Text(
      'NEW TODAY\n${roll!.quota}',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
    );
  }
}
