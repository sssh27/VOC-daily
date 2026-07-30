import 'package:flutter/material.dart';

/// A simple flippable flashcard. Tap to reveal the answer.
///
/// TODO: this is intentionally plain (no custom colors/fonts/animation) -
/// come back and restyle once the core logic works.
class Flashcard extends StatefulWidget {
  final String front;
  final String back;

  const Flashcard({super.key, required this.front, required this.back});

  @override
  State<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(covariant Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.front != widget.front) {
      _showBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showBack = !_showBack),
      child: Container(
        width: double.infinity,
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _showBack ? widget.back : widget.front,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
