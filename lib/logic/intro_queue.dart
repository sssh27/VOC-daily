/// 認識卡佇列的額度計數 + 補位邏輯(SPEC.md 6.4「額度補位機制」,v5 新增)。
///
/// 純函式風格,不碰 Flutter/資料庫——泛型 [T] 讓這個檔案不用依賴 Drift 的
/// `Card` 型別,方便單元測試(見 test/intro_queue_test.dart)。實際的卡片
/// 資料由呼叫端(`review_screen.dart` 的 `StudyScreen`)持有並傳入。
///
/// 規則:
/// - 按「下一個」(`confirmNext`)→ 計入當日新字額度,前進到下一張
/// - 按「我會了」(`markAlreadyKnown`)→ **不計入**額度,前進到下一張,
///   呼叫端要另外用 `CardRepository.replenishOneNewCard()` 拿到補位卡片,
///   透過 [replenish] 接到佇列最後面
library intro_queue;

class IntroQueue<T> {
  IntroQueue(List<T> initial) : _cards = List<T>.of(initial);

  final List<T> _cards;
  int _index = 0;

  /// 計入當日新字額度的張數(只有 [confirmNext] 會增加)。
  int learnedCount = 0;

  /// 目前這張卡,佇列跑完時是 null。
  T? get current => _index < _cards.length ? _cards[_index] : null;

  bool get isDone => _index >= _cards.length;

  /// 佇列裡還剩幾張(含目前這張)。
  int get remaining =>
      _index < _cards.length ? _cards.length - _index : 0;

  /// 按「下一個」:計入額度,前進到下一張。
  void confirmNext() {
    if (isDone) return;
    learnedCount++;
    _index++;
  }

  /// 按「我會了」:不計入額度,前進到下一張。
  void markAlreadyKnown() {
    if (isDone) return;
    _index++;
  }

  /// 補位:把新引入的卡片接到佇列最後面。[card] 是 null 代表倉庫已經沒有
  /// 未引入的卡片,不做任何事(天然停止條件,見 SPEC 6.4)。
  void replenish(T? card) {
    if (card != null) _cards.add(card);
  }
}
