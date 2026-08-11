import 'package:flutter/material.dart';

/// 在 [example] 裡把目標字出現的地方標成粗體,不挖空——目標單字已經
/// 顯示在題目上方,挖空沒有意義。
///
/// 【v9 修訂】比對規則是三段式(SPEC.md 6.3):
///
/// 1. 有 [exampleMatch] → 對這個字串做精確(大小寫敏感)比對,優先於
///    以下所有規則。找不到就直接整句原樣顯示,**不會**退回規則 2——
///    exampleMatch 是內容端明確指定要標的字串,找不到代表資料有誤,
///    硬套用別的規則反而可能標錯地方。
/// 2. 沒有 [exampleMatch] → 用 [word] 做大小寫不敏感的原始子字串比對。
///    **[word] 是句中某個較長單字的字首時,只會標到 [word] 自己的長度**
///    (例如 word=`clean`、句中是 `cleaning`,只有 `clean` 五個字母變
///    粗體,`ing` 不會)。之前這裡還有一個「詞形變化推測」的 fallback,
///    但驗證後發現它在結構上永遠不可能被觸發到——只要句中有 token 以
///    word 開頭,word 本身必然已經是子字串,前面的比對一定先命中——
///    已在 v9 移除(見 docs/agent-sync/QUESTIONS.md 的討論)。
/// 3. 找不到 → 整句原樣顯示,不報錯
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

  final start = lowerExample.indexOf(lowerWord);
  if (start == -1) {
    return [TextSpan(text: example)];
  }

  return _spans(example, start, start + word.length);
}

List<InlineSpan> _spans(String example, int start, int end) {
  const highlightStyle = TextStyle(fontWeight: FontWeight.bold);
  return [
    TextSpan(text: example.substring(0, start)),
    TextSpan(text: example.substring(start, end), style: highlightStyle),
    TextSpan(text: example.substring(end)),
  ];
}
