import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/widgets/word_highlight.dart';

/// 涵蓋 highlightWordSpans() 的 exampleMatch 比對規則(SPEC.md 6.3,v6)。

String _boldText(List<InlineSpan> spans) {
  for (final span in spans) {
    if (span is TextSpan &&
        span.style?.fontWeight == FontWeight.bold &&
        span.text != null) {
      return span.text!;
    }
  }
  return '';
}

String _plainConcat(List<InlineSpan> spans) {
  return spans
      .whereType<TextSpan>()
      .map((s) => s.text ?? '')
      .join();
}

void main() {
  test('有 exampleMatch 時,標粗的是該字串,不是 word', () {
    final spans = highlightWordSpans(
      'We hung out by the pool all afternoon.',
      'hang out',
      exampleMatch: 'hung out',
    );

    expect(_boldText(spans), 'hung out');
  });

  test('exampleMatch 不在例句裡時,不 crash,退回整句原樣顯示(不落回 word 比對)', () {
    final spans = highlightWordSpans(
      'We went out for dinner.',
      'hang out',
      exampleMatch: 'hung out',
    );

    expect(_boldText(spans), '');
    expect(_plainConcat(spans), 'We went out for dinner.');
  });

  test('沒有 exampleMatch 時,現有的三段式邏輯行為不變(回歸測試):word 直接比對', () {
    final spans = highlightWordSpans(
      'I always procrastinate when I have a big project.',
      'procrastinate',
    );

    expect(_boldText(spans), 'procrastinate');
  });

  test('word 是句中較長字的字首時,只標粗 word 自己的長度(現有行為,見 QUESTIONS.md)', () {
    // 實測發現:indexOf 的原始子字串比對一定會比 tokenRegex 詞形推測先
    // 命中(只要 word 是句中某個 token 的字首,indexOf 就會直接抓到,
    // 長度就是 word.length,不會延伸到整個 token)。也就是說 3.
    // 「詞形變化推測」那個分支目前實際上永遠不會被觸發到——已經寫進
    // docs/agent-sync/QUESTIONS.md 給國王餅確認要不要處理,這裡先如實
    // 記錄現在的行為,不要另外去改 word_highlight.dart 的邏輯。
    final spans = highlightWordSpans(
      'I hate cleaning the bathroom.',
      'clean',
    );

    expect(_boldText(spans), 'clean');
  });

  test('片語 hang out + exampleMatch: hung out,例句是過去式時正確標粗', () {
    final spans = highlightWordSpans(
      'We hung out at the cafe.',
      'hang out',
      exampleMatch: 'hung out',
    );

    expect(_boldText(spans), 'hung out');
    expect(_plainConcat(spans), 'We hung out at the cafe.');
  });

  test('exampleMatch 是空字串時,視同沒有 exampleMatch,退回 word 比對', () {
    final spans = highlightWordSpans(
      'I always procrastinate.',
      'procrastinate',
      exampleMatch: '',
    );

    expect(_boldText(spans), 'procrastinate');
  });
}
