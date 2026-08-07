import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/daily_roll.dart' as roll;
import '../providers.dart';
import 'decks_screen.dart';
import 'review_screen.dart';

/// 首頁(SPEC.md 6.1,v4)。整個 App 的主畫面,極簡:一個轉盤 + 一個
/// 「開始」按鈕 + 右上角 ☰ 通往單字庫。
///
/// 拉霸就地播放動畫(不再跳到獨立畫面,見 6.2 廢止說明)。
///
/// 嚴格禁止顯示:積壓數字、連續天數、完成率、任何評比,以及「複習」兩個字。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _rollDuration = Duration(milliseconds: 1500);
  static const _tickInterval = Duration(milliseconds: 60);
  static const _flashCandidates = [0, 3, 4, 5, 6];

  bool _loading = true;
  DailyRoll? _todaysRoll;
  int _studyQueueCount = 0;

  bool _rolling = false;
  int _displayNumber = 0;
  Timer? _rollTimer;
  final _flashRandom = Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(cardRepositoryProvider);
    final todaysRoll = await repo.todaysRoll();
    final queue = await repo.studyQueue();
    if (!mounted) return;
    setState(() {
      _todaysRoll = todaysRoll;
      _studyQueueCount = queue.length;
      _loading = false;
    });
  }

  void _startRoll() {
    if (_rolling || _todaysRoll != null) return;
    setState(() => _rolling = true);

    final repo = ref.read(cardRepositoryProvider);
    final stopwatch = Stopwatch()..start();

    _rollTimer = Timer.periodic(_tickInterval, (timer) async {
      if (stopwatch.elapsed >= _rollDuration) {
        timer.cancel();
        final backlog = await repo.backlogCount();
        final result = roll.rollNewCardQuota(backlog);
        await repo.recordRoll(quota: result.quota, wasCapped: result.wasCapped);
        if (result.quota > 0) {
          await repo.introduceNewCards(result.quota);
        }
        if (!mounted) return;
        setState(() => _rolling = false);
        await _load();
        return;
      }
      if (!mounted) return;
      setState(() {
        _displayNumber =
            _flashCandidates[_flashRandom.nextInt(_flashCandidates.length)];
      });
    });
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
        appBar: AppBar(title: const Text('VOC-daily')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final roll = _todaysRoll;
    final rolledToday = roll != null;
    final isJackpot = rolledToday && roll.quota == 0 && !roll.wasCapped;
    final wasCappedZero = rolledToday && roll.quota == 0 && roll.wasCapped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOC-daily'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _goDecks,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: rolledToday ? null : _startRoll,
              child: Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _studyQueueCount > 0 ? _goStudy : null,
              child: const Text('開始'),
            ),
            if (rolledToday && _studyQueueCount == 0) ...[
              const SizedBox(height: 12),
              Text(
                '今天沒有要學的了',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
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
      return Text('$_displayNumber', style: const TextStyle(fontSize: 40));
    }
    if (!rolledToday) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎰', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text('轉一下'),
        ],
      );
    }
    if (isJackpot) {
      return const Text(
        '🎉 今天放假,\n沒有新字',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      );
    }
    if (wasCappedZero) {
      return const Text(
        '今天先把\n之前的做完就好',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14),
      );
    }
    return Text(
      '今日新字:\n${roll!.quota} 個',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }
}
