import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_srs_app/logic/intro_queue.dart';

/// 涵蓋 IntroQueue 的額度計數 + 補位邏輯(SPEC.md 6.4「額度補位機制」,v5)。
void main() {
  test('按「下一個」(confirmNext)會計入 learnedCount 並前進', () {
    final queue = IntroQueue<String>(['a', 'b', 'c']);

    expect(queue.current, 'a');
    queue.confirmNext();

    expect(queue.learnedCount, 1);
    expect(queue.current, 'b');
  });

  test('按「我會了」(markAlreadyKnown)不計入 learnedCount,但會前進', () {
    final queue = IntroQueue<String>(['a', 'b', 'c']);

    queue.markAlreadyKnown();

    expect(queue.learnedCount, 0);
    expect(queue.current, 'b');
  });

  test('confirmNext 與 markAlreadyKnown 混用時,learnedCount 只算 confirmNext 的次數', () {
    final queue = IntroQueue<String>(['a', 'b', 'c', 'd']);

    queue.confirmNext(); // a -> 計入
    queue.markAlreadyKnown(); // b -> 不計入
    queue.confirmNext(); // c -> 計入

    expect(queue.learnedCount, 2);
    expect(queue.current, 'd');
  });

  test('replenish 把新卡接到佇列最後面', () {
    final queue = IntroQueue<String>(['a']);

    queue.markAlreadyKnown(); // a 用掉,佇列變空
    expect(queue.isDone, isTrue);

    queue.replenish('z');

    expect(queue.isDone, isFalse);
    expect(queue.current, 'z');
  });

  test('replenish(null) 代表倉庫已空,不做任何事、不會 crash', () {
    final queue = IntroQueue<String>(['a']);

    queue.markAlreadyKnown();
    expect(queue.isDone, isTrue);

    queue.replenish(null);

    expect(queue.isDone, isTrue);
    expect(queue.current, isNull);
  });

  test('佇列跑完後 isDone 為 true,current 為 null', () {
    final queue = IntroQueue<String>(['a']);

    expect(queue.isDone, isFalse);
    queue.confirmNext();

    expect(queue.isDone, isTrue);
    expect(queue.current, isNull);
  });

  test('佇列跑完後再呼叫 confirmNext / markAlreadyKnown 不會出錯或多算', () {
    final queue = IntroQueue<String>(['a']);
    queue.confirmNext();

    queue.confirmNext();
    queue.markAlreadyKnown();

    expect(queue.learnedCount, 1);
    expect(queue.isDone, isTrue);
  });

  test('remaining 反映目前還沒處理的張數(含目前這張)', () {
    final queue = IntroQueue<String>(['a', 'b', 'c']);

    expect(queue.remaining, 3);
    queue.confirmNext();
    expect(queue.remaining, 2);
  });
}
