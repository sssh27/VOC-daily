import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data/card_repository.dart';

/// 啟動時匯入內建牌組(SPEC.md 7.2,v6)。
///
/// 【v6 修訂】原本(`StarterDeckLoader.importIfEmpty()`)只吃一個寫死的
/// asset、且只要整個資料庫非空就整批跳過——這會讓已經有資料的使用者永遠
/// 拿不到新加的內建牌組。改成:
///
/// - 維護一份內建牌組清單([_deckAssets])
/// - 逐一依 `Deck.name` 判斷該牌組是否已存在,不存在才匯入
/// - 已存在的牌組**不覆蓋、不更新**,避免洗掉使用者的學習進度
/// - 單一牌組匯入失敗(檔案缺漏、JSON 格式錯)只記錄錯誤,不讓 App 崩潰,
///   繼續處理下一個
class DeckLoader {
  /// [assetPaths] 可選填,預設用內建牌組清單([_deckAssets])。測試時可以
  /// 注入包含不存在路徑的清單,驗證單一牌組失敗不影響其他牌組
  /// (見 test/multi_deck_loader_test.dart)。
  DeckLoader(this._repository, {List<String>? assetPaths})
      : _assetPaths = assetPaths ?? _deckAssets;

  final CardRepository _repository;
  final List<String> _assetPaths;

  /// 內建牌組清單。之後新增字庫只要:放 json 進 `assets/decks/` →
  /// 加進 `pubspec.yaml` → 加進這裡。
  static const _deckAssets = [
    'assets/decks/starter_deck.json',
    'assets/decks/cruise_travel.json',
  ];

  /// 依序檢查清單裡每個牌組,不存在的才匯入。
  Future<void> importMissingDecks() async {
    for (final assetPath in _assetPaths) {
      try {
        await _importOne(assetPath);
      } catch (e) {
        // 單一牌組壞掉不該讓整個 App 起不來,記錄下來繼續處理下一個。
        // ignore: avoid_print
        print('DeckLoader: 匯入 $assetPath 失敗,略過。錯誤:$e');
      }
    }
  }

  Future<void> _importOne(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final name = json['name'] as String;
    final alreadyExists = await _repository.deckExistsByName(name);
    if (alreadyExists) return;

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
              exampleMatch: c['exampleMatch'] as String?,
            ))
        .toList();

    await _repository.createDeckWithCards(
      name: name,
      topic: topic,
      cards: cards,
    );
  }
}
