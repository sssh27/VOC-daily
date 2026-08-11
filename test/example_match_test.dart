import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/widgets/word_highlight.dart';

/// 涵蓋 highlightWordSpans() 的比對規則(SPEC.md 6.3,v9:三段式,
/// 「詞形變化推測」的死碼分支已移除,見 docs/agent-sync/QUESTIONS.md)。

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

  test('word 是句中較長字的字首時,只標粗 word 自己的長度(鎖定行為,v9 定案)', () {
    // word="clean" 出現在句中的 "cleaning" 只會標粗前 5 個字母,不會
    // 延伸到整個單字。這是原本「詞形變化推測」死碼分支被移除後的正式
    // 行為(該分支結構上永遠不可能被觸發到,見 QUESTIONS.md 的討論)。
    // 需要抓到完整單字形態變化的情況一律用 exampleMatch 明確指定。
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
