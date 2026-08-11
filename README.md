# VOC-daily

英文單字/片語背誦 App(PWA)。每天用「拉霸」隨機決定新字量,用 SM-2
間隔重複演算法排程複習,學習畫面是四選一測驗。

線上網址:**https://sssh27.github.io/VOC-daily/**

## 核心機制

- **拉霸決定每日新字量**:不是固定配額,依積壓量骰出今天要學幾個新字
  (骰到 0 也是正常結果,代表放假),積壓越多骰子上限越低,避免棄坑。
- **SM-2 間隔重複**:`lib/logic/scheduler.dart`,已驗證、有完整測試,
  不能改動計算邏輯。
- **內容是預先產好的靜態字庫**,不是執行期呼叫 AI 生成——這樣才能純
  靜態部署,不需要後端、不需要金鑰、不怕金鑰外洩。目前 7 個牌組共 406
  張卡,見 `assets/decks/`。
- **零壓力設計**:沒做完的字不會有任何懲罰或提醒,沒有連續天數、正確率、
  完成率這類會讓人有罪惡感的數字。詳細產品原則見 `docs/SPEC.md`。

## 專案結構

```
lib/
├── main.dart                       # App 進入點
├── logic/
│   ├── scheduler.dart              # SM-2 演算法(核心,已測試,禁止改動邏輯)
│   ├── daily_roll.dart             # 拉霸權重與自動保護機制
│   ├── intro_queue.dart            # 認識卡佇列的額度計數 + 補位邏輯
│   ├── answer_grading.dart         # 依作答結果與反應時間換算 quality
│   ├── milestone.dart              # 累計字數里程碑判斷
│   └── completion_messages.dart    # 完成畫面文案池
├── data/
│   ├── database.dart                # Drift (SQLite) schema
│   └── card_repository.dart         # 所有資料庫查詢,畫面層不直接碰 Drift
├── services/
│   ├── deck_loader.dart             # 啟動時匯入內建牌組(依名稱判斷,不覆蓋既有進度)
│   └── ai_service.dart              # 開發階段的產字工具,不在正式主流程裡
├── screens/                         # home / review(學習) / decks(單字庫) / generate
└── widgets/                         # question_card / intro_card / word_highlight
assets/decks/                        # 內建牌組 JSON
test/                                # 單元測試(純函式 + repository 層,用 in-memory DB)
```

## 本機開發

### 1. 安裝 Flutter SDK

到 https://docs.flutter.dev/get-started/install 依平台指示安裝,裝完
跑 `flutter doctor` 確認基本項目過了。**目標是 Web,不需要 Android/iOS
的 toolchain 全過。**

### 2. Clone

```
git clone https://github.com/sssh27/VOC-daily.git
cd VOC-daily
flutter pub get
```

### 3. 產生 Drift 的程式碼

```
dart run build_runner build --delete-conflicting-outputs
```

`lib/data/database.dart` 改過(加欄位、加表)之後都要重跑這行,不然
`database.g.dart` 不會更新,編譯會失敗。

### 4. 啟動(⚠️ 一定要指定 `--web-port`)

```
flutter run -d chrome --web-port=8080
```

**不指定 `--web-port` 的話,每次啟動 Flutter 開發伺服器會隨機挑一個
port。** 瀏覽器的持久化儲存(IndexedDB/OPFS,資料庫就存在這裡)是綁定
在「origin」上,origin 包含 port——port 一變就等於換了一個全新的空
儲存空間,學習進度看起來會像每次都重置。**這不是 bug**,只要固定用
同一個 port 啟動,同一個分頁重新整理,資料就會還在。

### 5. 跑測試

```
flutter test
```

`test/scheduler_test.dart` 是排程演算法的驗證測試,禁止修改斷言。

## 用 AI 產字(開發階段的輔助工具,非正式功能)

正式版本不在執行期呼叫 AI(內容是預先審核過的靜態字庫,見
`docs/SPEC.md` 第 7 節),但 `generate_screen.dart` / `ai_service.dart`
保留下來作為開發階段的產字工具。要用的話,啟動時帶上金鑰:

```
flutter run -d chrome --web-port=8080 --dart-define=AI_API_KEY=sk-xxxx
```

沒帶這個參數時 AI 生成畫面會顯示「尚未設定 API 金鑰」,不影響其他功能。

## 部署

`main` 分支每次 push 會自動觸發 GitHub Actions(見
`.github/workflows/deploy.yml`)建置並部署到 GitHub Pages。字庫是打包
進 App 的 asset、資料庫在瀏覽器本機,**斷網也能完整使用**——第一次在
有網路的地方開啟過一次之後就行。

## 專案協作文件

`docs/SPEC.md` 是完整規格書,`docs/agent-sync/` 底下是協作用的溝通
文件(`TASKS.md` / `PROGRESS.md` / `QUESTIONS.md`),`CLAUDE.md`
記錄了整個專案的工作守則與絕對不要做的事。
