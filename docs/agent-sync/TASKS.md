# TASKS.md

> 國王餅(規格方)指派的工作。由上往下做,做完更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`(標題用 `## [未回答] ...`),不要自己猜。

---

## 這一輪:三件事

1. **註冊 5 個新牌組**(見 A)
2. **遊戲化與回饋**(見 B)
3. **移除 dotenv + PWA 部署**(見 G,**這是目前最高優先,它擋住所有部署**)

`docs/SPEC.md` 新增第 12、13 節,改寫第 11 節,並修訂 6.1、6.4、7.4–7.6。
請先讀完再動工。

**建議順序:G1(修 build 阻斷)→ A → B → G2(部署)。**
G1 沒修的話,乾淨環境根本 build 不起來,後面全部白做。

---

## A. 註冊 5 個新牌組

我新增了 210 張卡,共 5 個主題牌組,已放在 `assets/decks/`。
內容已通過粗體比對、跨牌組去重、欄位完整性、中文錯字四項檢查。

| 檔案 | 牌組名稱 | 張數 |
|---|---|---|
| `kitchen_food.json` | 廚房與飲食 | 47 |
| `home_cleaning.json` | 居家與清潔 | 44 |
| `clothing_shopping.json` | 服飾購物與付款 | 40 |
| `transport_directions.json` | 交通與方向 | 39 |
| `health_symptoms.json` | 身體與小症狀 | 40 |

### A1. `pubspec.yaml` 的 assets 補上五行

```yaml
    - assets/decks/kitchen_food.json
    - assets/decks/home_cleaning.json
    - assets/decks/clothing_shopping.json
    - assets/decks/transport_directions.json
    - assets/decks/health_symptoms.json
```

### A2. `lib/services/deck_loader.dart` 的 `_deckAssets` 補上同樣五個路徑

**順序把 `starter_deck.json` 放最後**,它是早期佔位測試資料,難度偏低。

---

## B. 遊戲化與回饋(SPEC 第 12 節)

### B0. 先讀 12.1 的設計立場

採**累積型**,禁止**損失趨避型**。streak / 愛心 / 排行榜 / 等級經驗值一律不做,
理由寫在 12.1(不只是產品偏好,是跟 SM-2 的間隔邏輯數學上衝突)。

12.7 有完整的禁止清單,動工前確認一遍。

### B1. 累計字數

定義:`Cards` 表中 `isIntroduced == true` 的筆數。單調遞增。

顯示三處:

| 位置 | 呈現 |
|---|---|
| 首頁 | 轉盤下方一行小字「你認識了 N 個字」 |
| 學習完成畫面 | 主要位置,較大字級 |
| 單字庫頁面頂端 | 總計數字 |

**首頁一定要顯示**,理由見 12.2(沒學習的日子也要看得到累積)。
6.1 的禁止清單已同步修訂,累計字數不在禁止之列。

### B2. 里程碑

門檻:`25, 50, 100, 200, 350, 500, 750, 1000`

跨越時,完成畫面改為特別版本(動畫 + 專屬文案)。**每個門檻只慶祝一次。**

需要新增 `AppSettings` 表(key-value,text/text),用 key `celebrated_milestone`
記錄已慶祝的最高門檻,預設 `0`。

**不要引入 `shared_preferences` 或任何新套件**,用 Drift 建表。
schema 版本要遞增,`onUpgrade` 加分支,改完跑:

```
dart run build_runner build --delete-conflicting-outputs
```

一次跨過多個門檻時**只慶祝最高的那個**,不要連彈好幾次。

### B3. 完成畫面文案輪替

從文案池隨機挑,不要固定「今天做完了」。池子與限制見 12.4。

**限制很重要:** 不得提及數量/正確率/花費時間,不得有督促或提醒明天再來的語氣。

### B4. 作答視覺回饋

| 情況 | 回饋 |
|---|---|
| 答對 | 正確選項變綠 + 短促放大回彈(約 150ms) |
| 答錯 | 選錯的變紅 + 輕微左右晃動(約 200ms),正確答案同時變綠 |
| 按「忘了」 | 正確答案變綠,**不做晃動** |

「忘了」不做晃動是刻意的——那是誠實回報,不該有懲罰感。

用 `AnimatedScale` / `TweenAnimationBuilder` 即可,**不要引入動畫套件**。

### B5. 拉霸動畫漸慢定格

目前等速跳動 1.5 秒直接停。改成間隔由快漸慢(例如 50ms 起,逐步拉長到 300ms),
總時長仍約 1.5–2 秒。

這是全 App 黏著力最高的瞬間,值得把手感做好。

### B6. 音效不做

見 12.8。PWA 在 iOS 有音訊手勢限制,且需引入套件與音檔資產,本輪不碰。

---

## C. 測試

1. 累計字數 = `isIntroduced == true` 的筆數,與牌組數量無關
2. 里程碑:累計 24 → 不觸發;25 → 觸發並寫入 `celebrated_milestone = 25`
3. 里程碑不重複:`celebrated_milestone` 已是 25 時,累計仍為 25 → 不再觸發
4. 一次跨多階:`celebrated_milestone = 25`、累計跳到 120 → 只慶祝 100,寫入 100
5. `AppSettings` 讀寫正確,key 不存在時回傳預設值不 crash
6. 完成文案池:隨機挑選不會回傳空字串

建議把里程碑判斷抽成純函式,例如:

```dart
int? milestoneToCelebrate({required int total, required int lastCelebrated});
```

這樣才好測,不要塞在 Widget State 裡。

`flutter test` 必須全綠,`test/scheduler_test.dart` 依然**禁止修改**。

---

## D. 需要 Shawn 本機驗證的項目

做完在 `PROGRESS.md` 列出:

1. 單字庫看得到 **7 個**牌組、總數 **406** 張
2. 既有牌組的學習進度沒有被重置
3. 首頁轉盤下方顯示「你認識了 N 個字」
4. 答對有回彈、答錯有晃動、按「忘了」沒有晃動
5. 轉盤動畫是漸慢定格而非等速
6. 粗體抽查:`come down with` → `coming down with`、`try on` → `try it on`

---

## E. 不要做的事

- 不要修改任何 `assets/decks/*.json`。發現錯誤寫進 `QUESTIONS.md`,由國王餅修正。
- 不要實作 12.7 禁止清單裡的任何項目。
- 不要刪 `ai_service.dart` / `generate_screen.dart`。
- 不要自行往下做 PWA manifest。

---

## F. Commit

1. `feat: add five themed vocabulary decks (210 cards)`
2. `chore: register new deck assets in pubspec and loader`
3. `feat: app settings table for milestone tracking`
4. `feat: show cumulative word count on home and completion screen`
5. `feat: milestone celebration on completion screen`
6. `feat: answer feedback animations and eased roll animation`
7. `test: cover milestone logic and cumulative count`

`git push` 若環境沒有認證,在 `PROGRESS.md` 註明,由 Shawn 本機執行。

---

## 完成後

更新 `PROGRESS.md` 後停下來等 review。


---

## G. 【最高優先】移除 dotenv + PWA 部署

### G1. 移除 flutter_dotenv —— 這是目前的建置阻斷點

**問題:** `main.dart` 有 `await dotenv.load(fileName: '.env')`,而 `.env` 在
`.gitignore` 裡,同時被登記為 `pubspec.yaml` 的 asset。

**缺少被登記的 asset 時 `flutter build` 會直接失敗。** 也就是說任何乾淨環境
(GitHub Actions、別台電腦重新 clone)都建置不起來。Shawn 本機能跑,
純粹是因為那個檔案還留著。

正式版不使用 AI(見 SPEC 7.1),所以直接移除這個相依:

1. `pubspec.yaml` 的 assets **移除 `.env` 那行**
2. `pubspec.yaml` 的 dependencies **移除 `flutter_dotenv`**
3. `main.dart` **移除** `dotenv.load()` 與 `flutter_dotenv` 的 import
4. `ai_service.dart` 改用 build-time 參數:

```dart
static const _apiKey = String.fromEnvironment('AI_API_KEY');

if (_apiKey.isEmpty) {
  throw Exception('AI_API_KEY 未設定。開發時請用 --dart-define=AI_API_KEY=... 啟動。');
}
```

**`ai_service.dart` 裡的安全警告註解仍然不要刪。**

改完確認 `flutter build web --release` 在沒有 `.env` 的情況下能成功。

### G2. PWA 部署

以下檔案**國王餅已經直接建好,不要重做、不要覆蓋**:

| 檔案 | 說明 |
|---|---|
| `web/manifest.json` | 名稱 VOC-daily、主題色 `#3F51B5`、`display: standalone` |
| `web/icons/Icon-{192,512}.png` | 一般圖示 |
| `web/icons/Icon-maskable-{192,512}.png` | maskable 圖示 |
| `web/favicon.png` | |
| `.github/workflows/deploy.yml` | GitHub Actions 自動建置部署 |

**你要做的:**

1. 確認 `web/index.html` 的 `<title>` 與 manifest 一致(改成 `VOC-daily`)
2. 確認 `index.html` 有正確的 `<meta name="theme-color" content="#3F51B5">`
3. 確認 `.gitignore` **沒有**排除 `web/icons/` 或 `.github/`
4. 確認 workflow 裡的 Flutter 版本(`3.44.8`)與 `pubspec.yaml` 的 SDK 限制相容

**base-href 的坑(已在 workflow 處理,但要知道):**
GitHub Pages 專案站台網址是 `https://sssh27.github.io/VOC-daily/`,不是根目錄。
建置必須帶 `--base-href /VOC-daily/`,漏掉會整頁 404 白畫面。

### G3. Shawn 要手動做的一次性設定(寫進 PROGRESS.md 提醒他)

GitHub repo → **Settings** → **Pages** → **Source** 選 **GitHub Actions**
(不是 Deploy from a branch)。只需設定一次。

### G4. 驗收(寫進 PROGRESS.md 給 Shawn 對照)

1. GitHub Actions workflow 綠燈
2. 手機開 `https://sssh27.github.io/VOC-daily/` 正常顯示
3. 瀏覽器選單有「加到主畫面」,加完桌面出現圖示
4. 從桌面圖示開啟是全螢幕(沒有網址列)
5. **開飛航模式後仍能完整使用**(字庫是打包的 asset,資料庫在瀏覽器本機)
6. 關掉再開,學習進度還在

第 5 點對郵輪情境很重要:船上網路又貴又慢,必須確保離線可用。
