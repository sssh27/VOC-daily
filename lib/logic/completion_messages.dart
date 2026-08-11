/// 完成畫面的文案(SPEC.md 12.4,v7 新增)。
///
/// 純函式,不碰 DB/UI,方便單元測試(見 test/completion_messages_test.dart)。
///
/// 限制(照抄 SPEC 12.4,動這個池子前重讀一次):
/// - 不得提及數量、正確率、花費時間、或任何評比
/// - 不得有督促、提醒明天再來、或任何帶有義務感的語氣
/// - 語氣輕鬆,不要過度熱情或說教
library completion_messages;

import 'dart:math';

const completionMessagePool = [
  '今天做完了',
  '收工',
  '就這樣,結束',
  '今天的份跑完了',
  '好了,可以去做別的事了',
];

/// 從文案池隨機挑一句。[random] 可注入以便測試。
String pickCompletionMessage({Random? random}) {
  final r = random ?? Random();
  return completionMessagePool[r.nextInt(completionMessagePool.length)];
}

/// 里程碑觸發時使用的專屬文案,取代一般文案池。
/// 里程碑本身就是累積型的數字(SPEC 12.2 允許顯示累計字數),不算評比,
/// 所以直接把門檻數字寫進文案裡沒問題。
String milestoneMessage(int milestone) => '你已經認識 $milestone 個字了';
