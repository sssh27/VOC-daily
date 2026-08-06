import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data/card_repository.dart';

/// 首次啟動時,如果資料庫是空的,自動匯入 assets/decks/starter_deck.json
/// 裡的內建牌組,讓使用者不需要設定 API key 就能開始用。
///
/// 只在 Decks 表是空的時候匯入,不會重複匯入。見 SPEC.md 第 7 節。
class StarterDeckLoader {
  StarterDeckLoader(this._repository);

  final CardRepository _repository;

  static const _assetPath = 'assets/decks/starter_deck.json';

  Future<void> importIfEmpty() async {
    final alreadyHasData = await _repository.hasAnyDeck();
    if (alreadyHasData) return;

    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final name = json['name'] as String;
    final topic = json['topic'] as String? ?? '';
    final cardsJson = (json['cards'] as List).cast<Map<String, dynamic>>();

    final cards = cardsJson
        .map((c) => (
              word: c['word'] as String,
              phonetic: c['phonetic'] as String? ?? '',
              meaning: c['meaning'] as String,
              example: c['example'] as String? ?? '',
              exampleZh: c['exampleZh'] as String? ?? '',
              avoidWith: (c['avoidWith'] as List?)?.map((e) => e.toString()).toList() ??
                  const <String>[],
            ))
        .toList();

    await _repository.createDeckWithCards(
      name: name,
      topic: topic,
      cards: cards,
    );
  }
}
