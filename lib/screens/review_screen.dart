import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/answer_grading.dart';
import '../logic/scheduler.dart';
import '../providers.dart';
import '../widgets/intro_card.dart';
import '../widgets/question_card.dart';

/// 學習畫面(SPEC.md 6.4,v4)。檔名維持 `review_screen.dart` 不變(避免大量
/// import 改動),但 class 改名 `StudyScreen`,畫面標題「學習」——全 App
/// 任何地方都不得出現「複習」兩個字。
///
/// 佇列 = 新字(前,認識卡模式,只給看不考)+ 到期字(後,四選一測驗模式)。
/// 答錯或按「忘了」的到期字會排到本次流程最後補考一次,補考結果不寫回資料庫。
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

enum _Mode { info, quiz }

enum _Phase { main, retry, done }

class _StudyScreenState extends ConsumerState<StudyScreen> {
  static const _correctRevealDuration = Duration(milliseconds: 1400);
  static const _wrongRevealDuration = Duration(seconds: 3);

  List<Card>? _mainQueue;
  int _mainIndex = 0;

  final List<Card> _retryQueue = [];
  int _retryIndex = 0;
  final Set<int> _alreadyRetried = {};

  _Phase _phase = _Phase.main;
  _Mode? _mode;
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
    if (_phase == _Phase.main) {
      final queue = _mainQueue;
      if (queue == null || _mainIndex >= queue.length) return null;
      return queue[_mainIndex];
    }
    if (_phase == _Phase.retry) {
      if (_retryIndex >= _retryQueue.length) return null;
      return _retryQueue[_retryIndex];
    }
    return null;
  }

  Future<void> _loadQueue() async {
    final repo = ref.read(cardRepositoryProvider);
    final queue = await repo.studyQueue();
    if (!mounted) return;
    setState(() {
      _mainQueue = queue;
      _mainIndex = 0;
      _phase = queue.isEmpty ? _Phase.done : _Phase.main;
    });
    await _prepareCurrent();
  }

  Future<void> _prepareCurrent() async {
    final card = _currentCard;
    if (card == null) return;

    setState(() {
      _selected = null;
      _gaveUp = false;
      _locked = false;
      _choices = null;
      _mode = null;
    });

    // 新字(lastReviewed == null)一律用認識卡,不考。
    if (card.lastReviewed == null) {
      setState(() => _mode = _Mode.info);
      return;
    }

    final repo = ref.read(cardRepositoryProvider);
    final distractors = await repo.distractorMeaningsFor(card, count: 3);

    if (!mounted) return;

    if (distractors.isEmpty) {
      // 選項不足(0 個):改用認識卡顯示,無法出題。
      setState(() => _mode = _Mode.info);
      return;
    }

    final choices = [card.meaning, ...distractors]..shuffle();
    setState(() {
      _mode = _Mode.quiz;
      _choices = choices;
    });

    _stopwatch
      ..reset()
      ..start();
  }

  /// 認識卡/資訊模式的「下一個」:quality 固定 4,一律寫回資料庫。
  Future<void> _confirmInfo() async {
    final card = _currentCard;
    if (card == null || _locked) return;
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

    await _advance();
  }

  /// 四選一測驗作答。[choice] 為 null 代表按了「忘了」。
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
    await _advance();
  }

  Future<void> _advance() async {
    if (!mounted) return;

    if (_phase == _Phase.main) {
      final nextIndex = _mainIndex + 1;
      if (nextIndex < (_mainQueue?.length ?? 0)) {
        setState(() => _mainIndex = nextIndex);
      } else if (_retryQueue.isNotEmpty) {
        setState(() {
          _phase = _Phase.retry;
          _retryIndex = 0;
        });
      } else {
        setState(() => _phase = _Phase.done);
        return;
      }
    } else if (_phase == _Phase.retry) {
      final nextIndex = _retryIndex + 1;
      if (nextIndex < _retryQueue.length) {
        setState(() => _retryIndex = nextIndex);
      } else {
        setState(() => _phase = _Phase.done);
        return;
      }
    } else {
      return;
    }

    await _prepareCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (_mainQueue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('學習')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_phase == _Phase.done) {
      return Scaffold(
        appBar: AppBar(title: const Text('學習')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('今天做完了', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('回首頁'),
              ),
            ],
          ),
        ),
      );
    }

    final card = _currentCard;
    if (card == null || _mode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('學習')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('學習')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _mode == _Mode.info
            ? _buildInfoMode(card)
            : _buildQuizMode(card),
      ),
    );
  }

  Widget _buildInfoMode(Card card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntroCard(
          word: card.word,
          phonetic: card.phonetic,
          meaning: card.meaning,
          example: card.example,
          exampleZh: card.exampleZh,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _locked ? null : _confirmInfo,
          child: const Text('下一個'),
        ),
      ],
    );
  }

  Widget _buildQuizMode(Card card) {
    final choices = _choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionCard(
          word: card.word,
          phonetic: card.phonetic,
          example: card.example,
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
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('忘了'),
          ),
          if (_locked && card.exampleZh.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              card.exampleZh,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
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

    if (revealResult) {
      if (isCorrectAnswer) {
        backgroundColor = Colors.green;
        foregroundColor = Colors.white;
      } else if (isSelected) {
        backgroundColor = Colors.red;
        foregroundColor = Colors.white;
      }
    }

    return ElevatedButton(
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
  }
}
