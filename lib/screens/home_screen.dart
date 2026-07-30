import 'package:flutter/material.dart';
import 'generate_screen.dart';
import 'review_screen.dart';

/// TODO: replace the hardcoded "0" with a real count of due cards
/// once lib/data/database.dart is wired up (see README Phase 1/2).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocab SRS')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('今天要複習: 0 張', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewScreen()),
              ),
              child: const Text('開始複習'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GenerateScreen()),
              ),
              child: const Text('AI 生成新單字'),
            ),
          ],
        ),
      ),
    );
  }
}
