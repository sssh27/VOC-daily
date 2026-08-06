import 'package:flutter/material.dart';

import 'word_highlight.dart';

/// 題目卡片(SPEC.md 6.3)。單面顯示,不可翻面 —— 翻卡模式已被否決。
///
/// 只顯示 word / phonetic / example(目標單字粗體)。`meaning` 和
/// `exampleZh` 不由這個元件顯示,由學習畫面在答題後另行呈現。
class QuestionCard extends StatelessWidget {
  final String word;
  final String phonetic;
  final String example;

  const QuestionCard({
    super.key,
    required this.word,
    required this.phonetic,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            word,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (phonetic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phonetic,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
          if (example.isNotEmpty) ...[
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: highlightWordSpans(example, word),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
