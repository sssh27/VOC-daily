import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/scheduler.dart';
import '../providers.dart';

/// 在 [example] 裡把 [word] 出現的地方標成粗體,而不是挖空——因為 word
/// 已經顯示在題目上方,挖空反而沒有意義。其他字保持原樣,不變色。比對規則
/// 跟原本挖空邏輯一樣:大小寫不敏感,單一詞時允許比對詞形變化(word 開頭
/// 的字),找不到就整句原樣顯示。
List<InlineSpan> _highlightWordSpans(String example, String word) {
  if (word.isEmpty || example.isEmpty) {
    return [TextSpan(text: example)];
  }

  final lowerExample = example.toLowerCase();
  final lowerWord = word.toLowerCase();

  int start = lowerExample.indexOf(lowerWord);
  int end = start == -1 ? -1 : start + word.length;

  if (start == -1 && !word.contains(' ')) {
    final tokenRegex = RegExp(r"[A-Za-z']+");
    for (final match in tokenRegex.allMatches(example)) {
      final token = match.group(0)!;
      if (token.toLowerCase().startsWith(lowerWord)) {
        start = match.start;
        end = match.end;
        break;
      }
    }
  }

  if (start == -1) {
    return [TextSpan(text: example)];
  }

  const highlightStyle = TextStyle(fontWeight: FontWeight.bold);

  return [
    TextSpan(text: example.substring(0, start)),
    TextSpan(text: example.substring(start, end), style: highlightStyle),
    TextSpan(text: example.substring(end)),
  ];
}

/// 複習畫面(四選一測驗版)。
///
/// 看英文單字 + 例句(單字本身標粗體/主色)選正確的中文意思:
/// - 一次答對 → SM-2 quality = 5
/// - 答錯 → 直接顯示正確答案 1-2 秒,自動跳下一題,quality = 0
///
/// 注意:這是應使用者要求,把原本規格書 6.4 的「翻卡 + 忘記了/有點難/普通/
/// 簡單」四個評分按鈕,換成四選一測驗。SM-2 排程邏輯(reviewCard())本身沒動。
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  static const _revealDuration = Duration(milliseconds: 1400);

  List<Card>? _queue;
  List<String> _meaningPool = [];
  int _index = 0;

  List<String>? _choices;
  String? _selected;
  bool _locked = false;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final repo = ref.read(cardRepositoryProvider);
    final queue = await repo.reviewQueue();
    final allCards = await repo.allCards();
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _meaningPool = allCards.map((c) => c.meaning).toSet().toList();
      _index = 0;
    });
    _buildChoicesForCurrent();
  }

  void _buildChoicesForCurrent() {
    final queue = _queue;
    if (queue == null || _index >= queue.length) return;
    final correct = queue[_index].meaning;

    final distractorPool = _meaningPool.where((m) => m != correct).toList()
      ..shuffle(_random);
    final distractors = distractorPool.take(3).toList();

    final choices = [correct, ...distractors]..shuffle(_random);

    setState(() {
      _choices = choices;
      _selected = null;
      _locked = false;
    });
  }

  Future<void> _select(String choice) async {
    if (_locked) return;
    final queue = _queue;
    if (queue == null || _index >= queue.length) return;
    final card = queue[_index];
    final correct = card.meaning;
    final isCorrect = choice == correct;

    setState(() {
      _selected = choice;
      _locked = true;
    });

    final state = ScheduleState(
      easiness: card.easiness,
      interval: card.interval,
      repetitions: card.repetitions,
      dueDate: card.dueDate,
    );
    final newState = reviewCard(state, isCorrect ? 5 : 0);
    final repo = ref.read(cardRepositoryProvider);
    await repo.submitReview(card.id, newState);

    await Future.delayed(_revealDuration);
    if (!mounted) return;

    setState(() => _index += 1);
    _buildChoicesForCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;

    if (queue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('複習')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_index >= queue.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('複習')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('今天的複習做完了', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('回首頁'),
              ),
            ],
          ),
        ),
      );
    }

    final card = queue[_index];
    final choices = _choices;

    return Scaffold(
      appBar: AppBar(title: const Text('複習')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (card.phonetic.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.phonetic,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                  if (card.example.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: _highlightWordSpans(card.example, card.word),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (choices != null)
              for (final choice in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChoiceButton(
                    label: choice,
                    isCorrectAnswer: choice == card.meaning,
                    isSelected: choice == _selected,
                    revealResult: _locked,
                    onTap: () => _select(choice),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool isCorrectAnswer;
  final bool isSelected;
  final bool revealResult;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.isCorrectAnswer,
    required this.isSelected,
    required this.revealResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    Color? foregroundColor;

    if (revealResult) {
      if (isCorrectAnswer) {
        backgroundColor = Colors.green;
        foregroundColor = Colors.white;
      } else if (isSelected) {
        backgroundColor = Colors.red;
        foregroundColor = Colors.white;
      }
    }

    return ElevatedButton(
      onPressed: revealResult ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor,
        disabledForegroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
