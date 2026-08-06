import 'package:flutter/material.dart';

/// 在 [example] 裡把 [word] 出現的地方標成粗體,不挖空——目標單字已經
/// 顯示在題目上方,挖空沒有意義。比對規則:
/// - 大小寫不敏感
/// - 單一詞時允許比對詞形變化(word 開頭的字,例如 word=`procrastinate`,
///   句中 `procrastinating` 也算)
/// - 找不到就整句原樣顯示,不報錯
///
/// 共用給 `question_card.dart` 和 `intro_card.dart`,兩者的例句粗體規則
/// 完全相同(SPEC.md 6.3)。
List<InlineSpan> highlightWordSpans(String example, String word) {
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
