# VOC-daily

英文單字/片語背誦 App。核心是用間隔重複演算法 (SM-2, 仿 Ebbinghaus 遺忘曲線) 自動排程複習,單字內容由 AI 依你指定的主題生成。

## 目前狀態

這是專案骨架 (scaffold),核心排程演算法 (`lib/logic/scheduler.dart`) 已經寫好且有單元測試,但 UI 和資料庫串接還是佔位版本 (見各檔案裡的 TODO)。

## 專案結構

```
lib/
├── main.dart              # App 進入點
├── logic/
│   └── scheduler.dart     # SM-2 間隔重複演算法 (核心,已測試,無外部依賴)
├── data/
│   └── database.dart      # Drift (SQLite) schema: Decks / Cards 表
├── services/
│   └── ai_service.dart    # AI 生成單字的呼叫 (目前直接呼叫 API,上架前要挪到後端)
├── screens/
│   ├── home_screen.dart
│   ├── review_screen.dart
│   └── generate_screen.dart
└── widgets/
    └── flashcard.dart      # 陽春字卡,先求能動,美術之後再改
test/
└── scheduler_test.dart    # 排程演算法的單元測試
```

## 在 Windows + VSCode 上跑起來

### 1. 安裝 Flutter SDK

1. 到 https://docs.flutter.dev/get-started/install/windows 下載並依指示安裝
2. 裝完在終端機打 `flutter doctor`,確認基本項目都打勾 (Android toolchain 這項一定要過)

### 2. VSCode 安裝套件

VSCode 裝 **Flutter** extension (會自動一起裝 Dart extension)。

### 3. Clone 這個 repo

```
git clone https://github.com/sssh27/VOC-daily.git
cd VOC-daily
```

### 4. 補上平台資料夾

這個 repo 沒有放 `android/` `ios/` 等資料夾 (那些是生成出來的,不用進版控)。在專案目錄下執行:

```
flutter create .
```

這只會補齊缺的平台檔案,不會動到 `lib/` 裡你的程式碼。

### 5. 設定 API Key

```
copy .env.example .env
```

打開 `.env`,把 `AI_API_KEY` 換成你自己的 key (先去 OpenAI 或你要用的服務申請)。

### 6. 安裝套件 + 產生 Drift 的程式碼

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

第二行是因為 `lib/data/database.dart` 用了 Drift,需要 code generation 才會生出 `database.g.dart`。以後改了資料表結構都要重跑這行。

### 7. 開 Android 模擬器,跑起來

VSCode 右下角選裝置 (或先在 Android Studio 開一台模擬器),然後按 F5,或terminal:

```
flutter run
```

### 8. 跑單元測試

```
flutter test
```

## 開發順序建議

1. **先不碰 AI**:手動塞測試資料到資料庫,把字卡 UI、翻面、四個評分按鈕、SM-2 排程串起來,確認 `dueDate` 邏輯正確
2. **驗證排程**:做個 debug 用的「時間快轉」按鈕,確認卡片會在正確天數後重新出現
3. **接 AI 生成**:`generate_screen.dart` 已經有基本串接,補上「存入資料庫」的邏輯
4. **通知**:用 `flutter_local_notifications` 提醒使用者今天有幾張卡要複習
5. **美術**:把 `widgets/flashcard.dart` 的陽春樣式換掉

## 上架 App Store 前必做

`lib/services/ai_service.dart` 目前直接在 App 裡呼叫 AI API,金鑰會被打包進 App。正式上架前一定要把這段邏輯搬到後端 (例如 Firebase Cloud Functions),App 只呼叫你自己的 endpoint,金鑰留在伺服器端,不然任何人反編譯都能挖出你的 key。
