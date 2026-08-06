import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/daily_roll.dart' as roll;
import '../providers.dart';
import 'review_screen.dart';

/// 拉霸畫面。依 SPEC.md 6.2:
/// 1. 顯示未轉動的轉盤 + 「轉動」按鈕
/// 2. 點「轉動」→ 約 1.5 秒的滾動動畫
/// 3. 定格在結果數字,依結果顯示不同文案
/// 4. 「開始學習」→ 執行 5.5 引入流程 → 導向複習畫面
class DailyRollScreen extends ConsumerStatefulWidget {
  const DailyRollScreen({super.key});

  @override
  ConsumerState<DailyRollScreen> createState() => _DailyRollScreenState();
}

class _DailyRollScreenState extends ConsumerState<DailyRollScreen> {
  static const _rollDuration = Duration(milliseconds: 1500);
  static const _tickInterval = Duration(milliseconds: 60);
  static const _flashCandidates = [0, 3, 4, 5, 6];

  bool _rolling = false;
  bool _done = false;
  int _displayNumber = 0;
  roll.RollResult? _result;
  Timer? _timer;
  final _flashRandom = Random();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRoll() async {
    if (_rolling || _done) return;
    setState(() => _rolling = true);

    final repo = ref.read(cardRepositoryProvider);
    final backlog = await repo.backlogCount();
    final result = roll.rollNewCardQuota(backlog);

    final stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(_tickInterval, (timer) {
      if (stopwatch.elapsed >= _rollDuration) {
        timer.cancel();
        _finishRoll(result);
        return;
      }
      setState(() {
        _displayNumber = _flashCandidates[_flashRandom.nextInt(_flashCandidates.length)];
      });
    });
  }

  Future<void> _finishRoll(roll.RollResult result) async {
    final repo = ref.read(cardRepositoryProvider);
    await repo.recordRoll(quota: result.quota, wasCapped: result.wasCapped);
    if (!mounted) return;
    setState(() {
      _rolling = false;
      _done = true;
      _result = result;
      _displayNumber = result.quota;
    });
  }

  Future<void> _startLearning() async {
    final result = _result;
    if (result == null) return;
    final repo = ref.read(cardRepositoryProvider);

    if (result.quota > 0) {
      final introduced = await repo.introduceNewCards(result.quota);
      if (introduced < result.quota && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('單字庫快用完了,去生成新的吧')),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
  }

  String get _resultText {
    final result = _result;
    if (result == null) return '';
    if (result.isJackpot) {
      return '🎉 JACKPOT!今天放假,不用背新字!';
    }
    if (result.quota == 0 && result.wasCapped) {
      return '今天先把之前的複習完就好';
    }
    return '今天的新單字:${result.quota} 個';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日轉盤')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                _rolling || _done ? '$_displayNumber' : '🎰',
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 24),
            if (_done)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _resultText,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            if (!_done)
              ElevatedButton(
                onPressed: _rolling ? null : _startRoll,
                child: Text(_rolling ? '轉動中...' : '轉動'),
              )
            else
              ElevatedButton(
                onPressed: _startLearning,
                child: const Text('開始學習'),
              ),
          ],
        ),
      ),
    );
  }
}
