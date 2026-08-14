import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'word_highlight.dart';

/// 認識卡(SPEC.md 6.3b,v4 新增)。新字第一次出現時使用,**只給看,不考**。
///
/// 理由:第一次見到的字直接考四選一是不合理的,使用者只能亂猜,產生的
/// quality 訊號是雜訊。按鈕(「下一個」)由學習畫面負責,不是這個元件的責任。
class IntroCard extends StatelessWidget {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String exampleZh;
  final String? exampleMatch;

  const IntroCard({
    super.key,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    required this.exampleZh,
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
          const SizedBox(height: 12),
          Text(
            meaning,
            style: AppTextStyles.body.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.secondary, height: 1, thickness: 1),
            const SizedBox(height: 8),
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
          if (exampleZh.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              exampleZh,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.tertiary),
            ),
          ],
        ],
      ),
    );
  }
}
