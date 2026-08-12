import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/completion_messages.dart';

/// 涵蓋完成畫面文案邏輯(SPEC.md 12.4,v7)。
void main() {
  test('文案池不是空的', () {
    expect(completionMessagePool, isNotEmpty);
  });

  test('文案池裡沒有空字串', () {
    expect(completionMessagePool.every((m) => m.trim().isNotEmpty), isTrue);
  });

  test('隨機挑選不會回傳空字串,且一定來自文案池', () {
    final random = Random(42);
    for (var i = 0; i < 50; i++) {
      final message = pickCompletionMessage(random: random);
      expect(message, isNotEmpty);
      expect(completionMessagePool, contains(message));
    }
  });

  test('固定 seed 時,多次呼叫仍可能覆蓋到池子裡不同的句子(不是永遠同一句)', () {
    final random = Random(1);
    final seen = <String>{};
    for (var i = 0; i < 100; i++) {
      seen.add(pickCompletionMessage(random: random));
    }
    expect(seen.length, greaterThan(1));
  });

  test('里程碑文案帶有正確的數字,且不是空字串', () {
    final message = milestoneMessage(100);
    expect(message, contains('100'));
    expect(message, isNotEmpty);
  });

  test('文案池的內容不得提及正確率、時間等評比字眼(基本檢查,大小寫不敏感)',
      () {
    const bannedWords = [
      '正確率', '花費', '分鐘', '秒', '%',
      'accuracy', 'streak', 'score', 'minutes', 'seconds', 'correct',
    ];
    for (final message in completionMessagePool) {
      final lower = message.toLowerCase();
      for (final banned in bannedWords) {
        expect(lower.contains(banned.toLowerCase()), isFalse,
            reason: '"$message" 不應該包含 "$banned"');
      }
    }
  });
}
