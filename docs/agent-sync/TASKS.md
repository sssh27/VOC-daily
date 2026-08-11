# TASKS.md

> 國王餅(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。

---

## 上一輪 review 結果

v7 + v8 全部完成。72 個測試、7 個牌組 406 張、dotenv 移除、PWA 檔案就位。

**特別肯定:** 你發現 `word_highlight.dart` 的死碼並停下來問,而不是自己改。
這正是 CLAUDE.md 要的做法。

**現在的狀態是「可以部署了」。這一輪工作很少,重點是把最後的雜項清乾淨。**

---

## A. 移除 `word_highlight.dart` 的死碼

你在 `QUESTIONS.md` 提的問題我裁定為**選項 1(移除)**,不是你傾向的選項 3。
完整理由見 `QUESTIONS.md` 該條的結論,摘要:

- 我驗算過,那個分支在**結構上不可達**(兩個觸發條件互斥),不是「目前剛好沒踩到」
- 既然不可能執行到,移除它**在定義上不可能改變行為**,回歸風險是零
- 留著的代價是實質的:SPEC 描述了不存在的功能,會誤導下一個讀的人

### 要做的

1. `lib/widgets/word_highlight.dart` 移除 `tokenRegex` fallback 分支
2. SPEC 6.3 的比對規則改成三段:
   `exampleMatch` → `word` 精確比對(大小寫不敏感) → 整句原樣顯示
   並明確寫出「`word` 是較長單字的字首時,只標到 `word` 自己的長度」
3. `test/example_match_test.dart` 補一個測試鎖住行為:
   `word=clean` + 例句含 `cleaning` → 只有 `clean` 五個字母粗體

---

## B. 持久化診斷 log 保留但降噪

你加的 `print('DB storage: ...')` 診斷正確、有價值,**保留**。

但改成只在 debug 模式輸出,避免正式版在 console 留訊息:

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  debugPrint('DB storage: ${result.chosenImplementation}, '
             'missing features: ${result.missingFeatures}');
}
```

用 `debugPrint` 取代 `print`,並拿掉 `// ignore: avoid_print`。

---

## C. README 更新

`README.md` 還停在最早的骨架版本,內容已經過時(提到 `.env`、提到 AI 生成是主要
內容來源)。改寫成反映現況:

1. 專案簡介:拉霸決定每日新字量 + SM-2 排程 + 四選一測驗
2. **本機開發指令**,特別註明 port 的坑:

   ```
   flutter run -d chrome --web-port=8080
   ```

   > **一定要指定 `--web-port`。** 不指定的話每次啟動會隨機挑 port,
   > 而瀏覽器的持久化儲存是綁定 origin(含 port)的,port 一變等於換了一個
   > 全新的空資料庫,學習進度看起來會像每次都重置。這不是 bug。

3. 改過 `database.dart` 後必跑 `dart run build_runner build --delete-conflicting-outputs`
4. 線上網址:`https://sssh27.github.io/VOC-daily/`
5. 開發時要用 AI 產字的話:`flutter run -d chrome --dart-define=AI_API_KEY=...`
6. 移除所有關於 `.env` 的說明(已經不用了)

---

## D. 不要做的事

- 不要修改任何 `assets/decks/*.json`
- 不要實作 SPEC 12.7 禁止清單裡的任何項目(streak / 愛心 / 排行榜 / 等級經驗值)
- 不要刪 `ai_service.dart` / `generate_screen.dart`,警告註解也不要刪
- 不要動 `.github/workflows/deploy.yml`、`web/manifest.json`、`web/icons/`

---

## E. Commit

1. `refactor: remove unreachable morphology fallback in word highlighting`
2. `chore: gate db storage diagnostic behind kDebugMode`
3. `docs: rewrite README for current architecture and web-port caveat`

---

## 完成後

更新 `PROGRESS.md` 後停下來。

下一步是 Shawn 在 GitHub 設定 Pages 來源並 push 觸發第一次部署,那部分不需要你做。
