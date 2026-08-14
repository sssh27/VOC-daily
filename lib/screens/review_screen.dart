import 'dart:math';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/answer_grading.dart';
import '../logic/completion_messages.dart';
import '../logic/intro_queue.dart';
import '../logic/milestone.dart';
import '../logic/scheduler.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/chrome_icon.dart';
import '../widgets/intro_card.dart';
import '../widgets/question_card.dart';

/// 學習畫面(SPEC.md 6.4,v5)。檔名維持 `review_screen.dart` 不變(避免大量
/// import 改動),但 class 是 `StudyScreen`,畫面標題「學習」——全 App
/// 任何地方都不得出現「複習」兩個字。
///
/// 流程:
/// 1. **新字(認識卡)**——`IntroQueue` 管理,只給看不考。「下一個」計入
///    當日新字額度;「我會了」連呼叫 3 次 `reviewCard(_, 5)`、不計入額度、
///    立刻從倉庫補位 1 張接到佇列最後面。
/// 2. **到期字(四選一測驗)**——答錯或按「忘了」的卡排到本次流程最後
///    補考一次,補考結果不寫回資料庫。
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

enum _DueMode { info, quiz }

enum _Phase { intro, due, retry, done }

class _StudyScreenState extends ConsumerState<StudyScreen> {
  static const _correctRevealDuration = Duration(milliseconds: 1400);
  static const _wrongRevealDuration = Duration(seconds: 3);

  IntroQueue<Card>? _introQueue;

  List<Card> _dueQueue = [];
  int _dueIndex = 0;

  final List<Card> _retryQueue = [];
  int _retryIndex = 0;
  final Set<int> _alreadyRetried = {};

  _Phase _phase = _Phase.intro;
  bool _loading = true;
  bool _warehouseExhausted = false;

  // 【v7】完成畫面內容(累計字數 + 里程碑/一般文案),只在第一次進入
  // _Phase.done 時算一次,見 _loadCompletionInfo()。
  bool _completionInfoLoaded = false;
  int _totalIntroduced = 0;
  int? _celebratingMilestone;
  String _completionMessage = '';

  _DueMode? _dueMode;
  List<String>? _choices;
  String? _selected;
  bool _gaveUp = false;
  bool _locked = false;

  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Card? get _currentCard {
    switch (_phase) {
      case _Phase.intro:
        return _introQueue?.current;
      case _Phase.due:
        return _dueIndex < _dueQueue.length ? _dueQueue[_dueIndex] : null;
      case _Phase.retry:
        return _retryIndex < _retryQueue.length
            ? _retryQueue[_retryIndex]
            : null;
      case _Phase.done:
        return null;
    }
  }

  Future<void> _loadQueue() async {
    final repo = ref.read(cardRepositoryProvider);
    final intro = await repo.newCards();
    final due = await repo.dueForStudyCards();
    final todaysRoll = await repo.todaysRoll();

    if (!mounted) return;

    final introQueue = IntroQueue<Card>(intro);
    // 倉庫在拉霸當下就不夠了(見 SPEC 5.5),先記下來,結束畫面才提示。
    final rollShortfall =
        todaysRoll != null && intro.length < todaysRoll.quota;

    setState(() {
      _introQueue = introQueue;
      _dueQueue = due;
      _dueIndex = 0;
      _warehouseExhausted = rollShortfall;
      _phase = introQueue.isDone ? _Phase.due : _Phase.intro;
      _loading = false;
    });

    await _prepareCurrent();
  }

  /// 只有到期字(模式 B)需要準備選項;新字一律是認識卡,不需要準備。
  Future<void> _prepareCurrent() async {
    _settlePhase();
    if (!mounted) return;

    final card = _currentCard;
    setState(() {
      _selected = null;
      _gaveUp = false;
      _locked = false;
      _choices = null;
      _dueMode = null;
    });

    if (_phase == _Phase.done) {
      await _loadCompletionInfo();
      return;
    }

    if (card == null || _phase == _Phase.intro) {
      return;
    }

    final repo = ref.read(cardRepositoryProvider);
    final distractors = await repo.distractorMeaningsFor(card, count: 3);
    if (!mounted) return;

    if (distractors.isEmpty) {
      setState(() => _dueMode = _DueMode.info);
      return;
    }

    final choices = [card.meaning, ...distractors]..shuffle();
    setState(() {
      _dueMode = _DueMode.quiz;
      _choices = choices;
    });

    _stopwatch
      ..reset()
      ..start();
  }

  /// 把 _phase 推進到第一個「有東西可做」的階段,連續空的階段會一路跳過。
  void _settlePhase() {
    if (_phase == _Phase.intro && (_introQueue?.isDone ?? true)) {
      _phase = _Phase.due;
    }
    if (_phase == _Phase.due && _dueIndex >= _dueQueue.length) {
      _phase = _retryQueue.isNotEmpty ? _Phase.retry : _Phase.done;
      _retryIndex = 0;
    }
    if (_phase == _Phase.retry && _retryIndex >= _retryQueue.length) {
      _phase = _Phase.done;
    }
  }

  /// 【v7】完成畫面只計算一次:累計字數(12.2)+ 里程碑判斷(12.3)+
  /// 文案(里程碑觸發用專屬文案,否則從文案池隨機挑,見 12.4)。
  Future<void> _loadCompletionInfo() async {
    if (_completionInfoLoaded) return;

    final repo = ref.read(cardRepositoryProvider);
    final total = await repo.introducedCount();
    final lastCelebrated = await repo.celebratedMilestone();
    final milestone = milestoneToCelebrate(
      total: total,
      lastCelebrated: lastCelebrated,
    );

    String message;
    if (milestone != null) {
      await repo.setCelebratedMilestone(milestone);
      message = milestoneMessage(milestone);
    } else {
      message = pickCompletionMessage();
    }

    if (!mounted) return;
    setState(() {
      _completionInfoLoaded = true;
      _totalIntroduced = total;
      _celebratingMilestone = milestone;
      _completionMessage = message;
    });
  }

  // ---------------------------------------------------------------------
  // 模式 A:認識卡(新字)
  // ---------------------------------------------------------------------

  /// 「下一個」:quality 固定 4,計入當日新字額度。
  Future<void> _introNext() async {
    final queue = _introQueue;
    final card = queue?.current;
    if (queue == null || card == null || _locked) return;
    setState(() => _locked = true);

    final state = ScheduleState(
      easiness: card.easiness,
      interval: card.interval,
      repetitions: card.repetitions,
      dueDate: card.dueDate,
    );
    final newState = reviewCard(state, 4);
    final repo = ref.read(cardRepositoryProvider);
    await repo.submitReview(card.id, newState);

    queue.confirmNext();
    await _advance();
  }

  /// 「我會了」:連呼叫 3 次 reviewCard(_, 5),不計入額度,立刻補位 1 張。
  Future<void> _introAlreadyKnown() async {
    final queue = _introQueue;
    final card = queue?.current;
    if (queue == null || card == null || _locked) return;
    setState(() => _locked = true);

    var state = ScheduleState(
      easiness: card.easiness,
      interval: card.interval,
      repetitions: card.repetitions,
      dueDate: card.dueDate,
    );
    for (var i = 0; i < 3; i++) {
      state = reviewCard(state, 5);
    }
    final repo = ref.read(cardRepositoryProvider);
    await repo.submitReview(card.id, state);

    queue.markAlreadyKnown();

    final replacement = await repo.replenishOneNewCard();
    queue.replenish(replacement);
    if (replacement == null) {
      _warehouseExhausted = true;
    }

    await _advance();
  }

  // ---------------------------------------------------------------------
  // 模式 B:到期字(四選一測驗 / 選項不足時的認識卡 fallback)
  // ---------------------------------------------------------------------

  /// 到期字選項不足(0 個 distractor)時的 fallback:改用認識卡顯示,
  /// 按「下一個」以 quality 4 計。**補考階段不寫回資料庫**(A2 修正)。
  Future<void> _confirmDueInfo() async {
    final card = _currentCard;
    if (card == null || _locked) return;
    setState(() => _locked = true);

    if (_phase != _Phase.retry) {
      final state = ScheduleState(
        easiness: card.easiness,
        interval: card.interval,
        repetitions: card.repetitions,
        dueDate: card.dueDate,
      );
      final newState = reviewCard(state, 4);
      final repo = ref.read(cardRepositoryProvider);
      await repo.submitReview(card.id, newState);
    }

    await _advanceDueOrRetry();
  }

  Future<void> _answerQuiz({String? choice, required bool gaveUp}) async {
    final card = _currentCard;
    if (card == null || _locked) return;

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed;
    final isCorrect = !gaveUp && choice == card.meaning;

    setState(() {
      _selected = choice;
      _gaveUp = gaveUp;
      _locked = true;
    });

    final isRetry = _phase == _Phase.retry;

    if (!isRetry) {
      // 只有正式作答(非補考)才寫回資料庫,見 SPEC 6.4「答錯補考機制」。
      final quality = gradeAnswer(
        isCorrect: isCorrect,
        gaveUp: gaveUp,
        elapsed: elapsed,
      );
      final state = ScheduleState(
        easiness: card.easiness,
        interval: card.interval,
        repetitions: card.repetitions,
        dueDate: card.dueDate,
      );
      final newState = reviewCard(state, quality);
      final repo = ref.read(cardRepositoryProvider);
      await repo.submitReview(card.id, newState);

      if (!isCorrect && !_alreadyRetried.contains(card.id)) {
        _alreadyRetried.add(card.id);
        _retryQueue.add(card);
      }
    }

    final revealDuration =
        isCorrect ? _correctRevealDuration : _wrongRevealDuration;
    await Future.delayed(revealDuration);
    await _advanceDueOrRetry();
  }

  Future<void> _advanceDueOrRetry() async {
    if (_phase == _Phase.due) {
      _dueIndex++;
    } else if (_phase == _Phase.retry) {
      _retryIndex++;
    }
    await _advance();
  }

  Future<void> _advance() async {
    if (!mounted) return;
    setState(() {});
    await _prepareCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('STUDY')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_phase == _Phase.done) {
      return Scaffold(
        appBar: AppBar(title: const Text('STUDY')),
        body: Center(
          child: !_completionInfoLoaded
              ? const CircularProgressIndicator()
              : _buildCompletionContent(context),
        ),
      );
    }

    final card = _currentCard;
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('STUDY')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('STUDY')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _phase == _Phase.intro
            ? _buildIntroMode(card)
            : _buildDueMode(card),
      ),
    );
  }

  /// 完成畫面內容(SPEC.md 12.2–12.4)。里程碑觸發時用專屬文案 +
  /// 一個短促的放大動畫;否則是文案池隨機挑的一句,兩種情況都要顯示
  /// 「你認識了 N 個字」(累計字數,主要位置、較大字級)。
  /// 仍然不顯示分數、正確率、答對幾題或任何評比。
  Widget _buildCompletionContent(BuildContext context) {
    final isMilestone = _celebratingMilestone != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMilestone)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: const ChromeIcon(Icons.auto_awesome, size: 40),
          ),
        if (isMilestone) const SizedBox(height: 8),
        Text(
          _completionMessage,
          style: AppTextStyles.caption.copyWith(color: AppColors.tertiary),
        ),
        const SizedBox(height: 16),
        Text(
          'You know $_totalIntroduced words',
          style: AppTextStyles.displayMedium.copyWith(color: AppColors.primary),
        ),
        if (_warehouseExhausted) ...[
          const SizedBox(height: 12),
          Text(
            'Your word bank is running low',
            style: AppTextStyles.body.copyWith(color: AppColors.tertiary),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          style: appPrimaryButtonStyle,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('HOME'),
        ),
      ],
    );
  }

  Widget _buildIntroMode(Card card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntroCard(
          word: card.word,
          phonetic: card.phonetic,
          meaning: card.meaning,
          example: card.example,
          exampleZh: card.exampleZh,
          exampleMatch: card.exampleMatch,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _locked ? null : _introNext,
                child: const Text('NEXT'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _locked ? null : _introAlreadyKnown,
                child: const Text('I KNOW THIS'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDueMode(Card card) {
    if (_dueMode == _DueMode.info) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntroCard(
            word: card.word,
            phonetic: card.phonetic,
            meaning: card.meaning,
            example: card.example,
            exampleZh: card.exampleZh,
            exampleMatch: card.exampleMatch,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _locked ? null : _confirmDueInfo,
            child: const Text('NEXT'),
          ),
        ],
      );
    }

    final choices = _choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionCard(
          word: card.word,
          phonetic: card.phonetic,
          example: card.example,
          exampleMatch: card.exampleMatch,
        ),
        const SizedBox(height: 24),
        if (choices == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceButton(
                label: choice,
                isCorrectAnswer: choice == card.meaning,
                isSelected: !_gaveUp && choice == _selected,
                revealResult: _locked,
                onTap: () => _answerQuiz(choice: choice, gaveUp: false),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _locked ? null : () => _answerQuiz(gaveUp: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tertiary,
              side: const BorderSide(color: AppColors.tertiary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('I FORGOT'),
          ),
          if (_locked && card.exampleZh.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              card.exampleZh,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.tertiary),
            ),
          ],
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool isCorrectAnswer;
  final bool isSelected;
  final bool revealResult;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.isCorrectAnswer,
    required this.isSelected,
    required this.revealResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    Color? foregroundColor;
    // 【v7/12.5】答對:正確選項綠 + 短促放大回彈。答錯:選錯的紅 +
    // 輕微晃動,正確答案同時變綠(不晃動)。按「忘了」:isSelected 永遠是
    // false(見 _buildDueMode 的呼叫端),所以不會晃動,只有正確答案變綠。
    var bounce = false;
    var shake = false;

    if (revealResult) {
      if (isCorrectAnswer) {
        backgroundColor = AppColors.correctBackground;
        foregroundColor = AppColors.correctForeground;
        if (isSelected) bounce = true; // 使用者自己選對了
      } else if (isSelected) {
        backgroundColor = AppColors.incorrectBackground;
        foregroundColor = AppColors.incorrectForeground;
        shake = true;
      }
    }

    Widget button = ElevatedButton(
      onPressed: revealResult ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor,
        disabledForegroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );

    // 條件式包一層動畫 widget——只有在剛進入回饋狀態的那次 build 才會被
    // 新建立,天然形成「只播一次」的觸發時機,不需要額外的 AnimationController。
    if (bounce) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: button,
      );
    } else if (shake) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (context, t, child) {
          final offset = sin(t * pi * 4) * 6 * (1 - t);
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: button,
      );
    }

    return button;
  }
}
