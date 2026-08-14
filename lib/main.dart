import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'services/deck_loader.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VocabApp()));
}

class VocabApp extends StatelessWidget {
  const VocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocab SRS',
      theme: appTheme,
      // SPEC 16.9:網頁版寬度上限,全域一次,不在各畫面各包一次。
      // 430 是設計稿基準寬度,超出的區域露出 scaffoldBackgroundColor
      // (AppColors.neutral)。
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const _AppBootstrap(),
    );
  }
}

/// 第一次啟動時,先確認內建牌組已匯入(見 SPEC.md 第 7 節),再顯示首頁。
class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(cardRepositoryProvider);
    _ready = DeckLoader(repo).importMissingDecks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeScreen();
      },
    );
  }
}
