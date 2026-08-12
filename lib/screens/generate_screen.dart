import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

/// AI 生成畫面。依 SPEC.md 6.6。
///
/// 重要:生成的卡片一律 isIntroduced = false,只是進倉庫等拉霸決定何時
/// 進入學習循環,不會生成完就直接開始學。
class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _topicController = TextEditingController();
  int _count = 10;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<GeneratedCard> _preview = [];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await AiService.generateCards(
        topic: _topicController.text,
        count: _count,
      );
      setState(() => _preview = cards);
    } on AiServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addToDeck() async {
    if (_preview.isEmpty) return;
    setState(() => _saving = true);
    try {
      final topic = _topicController.text.trim();
      final repo = ref.read(cardRepositoryProvider);
      await repo.createDeckWithCards(
        name: topic.isEmpty ? '未命名牌組' : topic,
        topic: topic,
        cards: _preview
            .map((c) => (
                  word: c.word,
                  phonetic: c.phonetic,
                  meaning: c.meaning,
                  example: c.example,
                  exampleZh: c.exampleZh,
                  avoidWith: const <String>[],
                  exampleMatch: null,
                ))
            .toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 生成單字')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '想學什麼類型？例如：多益商用英文 B2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('數量：'),
                const SizedBox(width: 8),
                for (final n in [10, 20, 30])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: _count == n,
                      onSelected: (_) => setState(() => _count = n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('生成'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _preview.length,
                itemBuilder: (context, i) {
                  final c = _preview[i];
                  return ListTile(
                    title: Text(c.word),
                    subtitle: Text(c.meaning),
                  );
                },
              ),
            ),
            if (_preview.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _generate,
                      child: const Text('重新生成'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _addToDeck,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('加入牌組'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
