import 'package:flutter/material.dart';
import '../widgets/flashcard.dart';

/// TODO: load real due cards from the database (AppDatabase.dueCards) and
/// call reviewCard() from lib/logic/scheduler.dart when a rating button
/// is tapped, then save the returned ScheduleState back to the row.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('複習')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Flashcard(front: 'procrastinate', back: '拖延'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ratingButton(context, '忘記了', 0),
                _ratingButton(context, '有點難', 3),
                _ratingButton(context, '普通', 4),
                _ratingButton(context, '簡單', 5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingButton(BuildContext context, String label, int quality) {
    return ElevatedButton(
      onPressed: () {
        // TODO: call reviewCard(state, quality) and persist the result
      },
      child: Text(label),
    );
  }
}
