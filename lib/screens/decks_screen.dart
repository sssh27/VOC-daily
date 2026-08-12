import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

/// 單字庫(SPEC.md 6.5,v4:原「牌組列表」降級為次要畫面)。
/// 從首頁右上角 ☰ 進入,不是主流程的一部分。用途只有兩個:看看庫存、
/// 管理 AI 生成的批次。每個牌組顯示「已學 X / Y 字」與進度條。
///
/// 牌組(Deck)概念保留在資料層:AI 一次生成一批卡片需要容器管理,而且
/// 四選一的干擾項優先從同一牌組挑選才有鑑別度(見 6.5)。
class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DeckRow {
  final Deck deck;
  final int learned;
  final int total;
  _DeckRow(this.deck, this.learned, this.total);
}

class _DecksScreenState extends ConsumerState<DecksScreen> {
  List<_DeckRow>? _rows;
  int _totalIntroduced = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(cardRepositoryProvider);
    final decks = await repo.allDecks();
    final rows = <_DeckRow>[];
    for (final deck in decks) {
      final (learned, total) = await repo.deckProgress(deck.id);
      rows.add(_DeckRow(deck, learned, total));
    }
    final introduced = await repo.introducedCount();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalIntroduced = introduced;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Scaffold(
      appBar: AppBar(title: const Text('LIBRARY')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'You know $_totalIntroduced words',
                      style: AppTextStyles.displayMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  );
                }
                final row = rows[i - 1];
                final progress = row.total == 0 ? 0.0 : row.learned / row.total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.deck.name,
                        style: AppTextStyles.bodyStrong
                            .copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${row.learned} / ${row.total} learned',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.tertiary),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          color: AppColors.primary,
                          backgroundColor: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
