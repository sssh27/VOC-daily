import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import 'generate_screen.dart';

/// 牌組列表。依 SPEC.md 6.5:每個牌組顯示「已學 X / Y 字」與進度條。
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
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Future<void> _goToGenerate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GenerateScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Scaffold(
      appBar: AppBar(title: const Text('我的牌組')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                final progress = row.total == 0 ? 0.0 : row.learned / row.total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.deck.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('已學 ${row.learned} / ${row.total} 字'),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: progress),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _goToGenerate,
            child: const Text('+ 新增牌組'),
          ),
        ),
      ),
    );
  }
}
