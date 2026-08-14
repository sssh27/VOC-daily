import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'word_highlight.dart';

/// 題目卡片(SPEC.md 6.3)。單面顯示,不可翻面 —— 翻卡模式已被否決。
///
/// 只顯示 word / phonetic / example(目標單字粗體)。`meaning` 和
/// `exampleZh` 不由這個元件顯示,由學習畫面在答題後另行呈現。
class QuestionCard extends StatelessWidget {
  final String word;
  final String phonetic;
  final String example;
  final String? exampleMatch;

  const QuestionCard({
    super.key,
    required this.word,
    required this.phonetic,
    required this.example,
    this.exampleMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F22243A), // #22243A 6%
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: AppTextStyles.headline.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          if (phonetic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phonetic,
              style: AppTextStyles.caption.copyWith(color: AppColors.tertiary),
            ),
          ],
          if (example.isNotEmpty) ...[
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.body.copyWith(color: AppColors.primary),
                children: highlightWordSpans(
                  example,
                  word,
                  exampleMatch: exampleMatch,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
