import 'package:flutter/material.dart';

/// 依 SPEC.md 6.3 挖空規則,把 [example] 裡出現的 [word] 換成底線。
///
/// - 大小寫不敏感比對
/// - 若 example 中找不到 word 原形,嘗試比對 word 開頭的字(處理詞形變化,
///   例如 word=`procrastinate`,句中是 `procrastinating`)
/// - 完全找不到就原句照顯示,不報錯
///
/// 注意:當 word 是片語(多個單字組成)時,詞形變化的比對只做「完整片語」
/// 的大小寫不敏感比對,不會嘗試比對片語中某個字的詞形變化 —— 這是 SPEC.md
/// 9.3 列出的模糊地帶,先以最簡單、不報錯的方式處理。
String blankOutWord(String example, String word) {
  if (word.isEmpty || example.isEmpty) return example;

  final lowerExample = example.toLowerCase();
  final lowerWord = word.toLowerCase();

  // 1. 完整字/片語的大小寫不敏感比對
  final exactIndex = lowerExample.indexOf(lowerWord);
  if (exactIndex != -1) {
    return example.substring(0, exactIndex) +
        '______' +
        example.substring(exactIndex + word.length);
  }

  // 2. 詞形變化:找 example 裡以 word 開頭的字(單一詞情況)
  if (!word.contains(' ')) {
    final tokenRegex = RegExp(r"[A-Za-z']+");
    for (final match in tokenRegex.allMatches(example)) {
      final token = match.group(0)!;
      if (token.toLowerCase().startsWith(lowerWord)) {
        return example.substring(0, match.start) +
            '______' +
            example.substring(match.end);
      }
    }
  }

  // 3. 完全找不到,原句照顯示
  return example;
}

/// 雙面單字卡,點擊翻面。
///
/// 正面:word / phonetic / 挖空後的 example
/// 背面:word / phonetic / meaning / 完整 example / exampleZh
///
/// 評分按鈕不是這個元件的責任,翻到背面時透過 [onFlipped] 通知外層。
class Flashcard extends StatefulWidget {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String exampleZh;
  final VoidCallback? onFlipped;

  const Flashcard({
    super.key,
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    required this.exampleZh,
    this.onFlipped,
  });

  @override
  State<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(covariant Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word || oldWidget.example != widget.example) {
      _showBack = false;
    }
  }

  void _handleTap() {
    if (_showBack) return;
    setState(() => _showBack = true);
    widget.onFlipped?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _showBack ? _buildBack(context) : _buildFront(context),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    final blanked = blankOutWord(widget.example, widget.word);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.word,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.phonetic.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.phonetic,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
        if (blanked.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(blanked, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        Text(
          '(點一下看答案)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBack(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.word,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.phonetic.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.phonetic,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          widget.meaning,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (widget.example.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(widget.example, textAlign: TextAlign.center),
        ],
        if (widget.exampleZh.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.exampleZh,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }
}
