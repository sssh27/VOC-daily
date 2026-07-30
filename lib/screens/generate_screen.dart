import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final _topicController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<GeneratedCard> _preview = [];

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await AiService.generateCards(topic: _topicController.text);
      setState(() => _preview = cards);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 生成單字')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '想學什麼類型？例如：多益商用英文 B2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('生成'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _preview.length,
                itemBuilder: (context, i) {
                  final c = _preview[i];
                  // TODO: add a "save all to deck" button that writes
                  // these into the database via a card_repository.dart
                  return ListTile(
                    title: Text(c.word),
                    subtitle: Text(c.meaning),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
