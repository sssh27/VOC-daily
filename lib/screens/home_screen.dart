import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import 'daily_roll_screen.dart';
import 'decks_screen.dart';
import 'review_screen.dart';

/// 首頁。依 SPEC.md 6.1:
/// - 今天還沒拉霸 → 顯示拉霸按鈕(+ 若有到期卡片,顯示「開始複習」)
/// - 今天已經拉過 → 顯示今日新字 / 待複習張數 / 開始複習 / 我的牌組
///
/// 禁止顯示積壓數字、連續天數、完成率(見 6.1)。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DailyRoll? _todaysRoll;
  int _dueCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(cardRepositoryProvider);
    final roll = await repo.todaysRoll();
    final due = await repo.dueCount();
    if (!mounted) return;
    setState(() {
      _todaysRoll = roll;
      _dueCount = due;
      _loading = false;
    });
  }

  Future<void> _goToRoll() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailyRollScreen()),
    );
    _load();
  }

  Future<void> _goToReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
    _load();
  }

  void _goToDecks() {
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

    return Scaffold(
      appBar: AppBar(title: const Text('VOC-daily')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!rolledToday) ...[
              GestureDetector(
                onTap: _goToRoll,
                child: Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎰', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('今日轉盤'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_dueCount > 0)
                ElevatedButton(
                  onPressed: _goToReview,
                  child: const Text('開始複習'),
                ),
            ] else ...[
              Text(
                isJackpot ? '今天放假!沒有新字' : '今日新字:${roll.quota} 個',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                '待複習:$_dueCount 張',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _dueCount > 0 ? _goToReview : null,
                child: const Text('開始複習'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _goToDecks,
                child: const Text('我的牌組'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
