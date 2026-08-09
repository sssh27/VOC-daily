import 'package:flutter/material.dart';

/// 在 [example] 裡把目標字出現的地方標成粗體,不挖空——目標單字已經
/// 顯示在題目上方,挖空沒有意義。
///
/// 【v6 修訂】比對規則改成依序判斷(SPEC.md 6.3):
///
/// 1. 有 [exampleMatch] → 對這個字串做精確(大小寫敏感)比對,優先於
///    以下所有規則。找不到就直接整句原樣顯示,**不會**退回規則 2/3——
///    exampleMatch 是內容端明確指定要標的字串,找不到代表資料有誤,
///    硬套用別的規則反而可能標錯地方。
/// 2. 沒有 [exampleMatch] → 用 [word] 做大小寫不敏感比對
/// 3. 仍找不到,且 [word] 不含空格 → 允許詞形變化(word 開頭的字,
///    例如 word=`procrastinate`,句中 `procrastinating` 也算)
/// 4. 都找不到 → 整句原樣顯示,不報錯
///
/// 刻意不在這裡實作不規則動詞表或詞形還原規則(理由見 SPEC.md 6.3):
/// 片語動詞的時態變化(`hang out` → `hung out`)一律靠內容端提供
/// [exampleMatch] 處理,而不是靠程式猜。
///
/// 共用給 `question_card.dart` 和 `intro_card.dart`,兩者的例句粗體規則
/// 完全相同。
List<InlineSpan> highlightWordSpans(
  String example,
  String word, {
  String? exampleMatch,
}) {
  if (example.isEmpty) {
    return [TextSpan(text: example)];
  }

  if (exampleMatch != null && exampleMatch.isNotEmpty) {
    final start = example.indexOf(exampleMatch);
    if (start == -1) {
      return [TextSpan(text: example)];
    }
    return _spans(example, start, start + exampleMatch.length);
  }

  if (word.isEmpty) {
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

  return _spans(example, start, end);
}

List<InlineSpan> _spans(String example, int start, int end) {
  const highlightStyle = TextStyle(fontWeight: FontWeight.bold);
  return [
    TextSpan(text: example.substring(0, start)),
    TextSpan(text: example.substring(start, end), style: highlightStyle),
    TextSpan(text: example.substring(end)),
  ];
}
