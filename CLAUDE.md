# CLAUDE.md — 專案常駐工作守則

> 這個檔案會在每次開啟專案時自動載入。**開始任何工作前先讀完。**

---

## 這個專案是什麼

英文單字/片語背誦 App(PWA)。核心是用 SM-2 間隔重複演算法排程複習,
每日新字量由「拉霸」隨機決定,並有防止使用者棄坑的自動保護機制。

- **專案位置**:`C:\Users\shawn\VOC-daily`
- **GitHub**:https://github.com/sssh27/VOC-daily
- **技術**:Flutter 3.44.8 / Dart 3.12.2,目標平台 **Web (PWA)**
- **開發環境**:Windows,無 Mac,不需考慮 iOS 原生打包

---

## 三方協作模式

這個專案有兩個 Claude agent 協作,加上專案擁有者:

| 角色 | 職責 |
|---|---|
| **Shawn**(人) | 產品決策、在本機跑 `flutter test` / `git push`、觸發兩個 agent |
| **老大**(規格方) | 制定與維護 `docs/SPEC.md`、code review、回答問題、指派工作 |
| **老二**(實作方) | 寫 code、跑測試、修 bug、回報進度 |

### 重要限制

**兩個 agent 無法直接通訊,也叫不醒對方。** 所有溝通都透過 `docs/agent-sync/`
底下的檔案進行,由 Shawn 負責在兩邊之間切換觸發。

所以:**不要在回覆裡寫「請把這段複製給對方」之類的話。** 直接把內容寫進對應的
檔案就好,對方讀得到。

---

## 溝通檔案

```
docs/
├── SPEC.md                              ← 規格書,唯一真實來源
└── agent-sync/
    ├── TASKS.md                         ← 老大指派給老二的工作(老大寫,老二讀)
    ├── PROGRESS.md                      ← 老二的工作日誌(老二寫,老大讀)
    ├── QUESTIONS.md                     ← 老二問、老大答(雙向)
    ├── REVIEW_NOTES.md                  ← 老大的 code review 意見(選用)
    └── archive/                         ← 歷史文件
```

**規則:所有溝通文件一律放在 `docs/agent-sync/` 底下。專案根目錄只保留
`README.md` 和本檔案。**

---

## 開工流程

### 如果你是老二(實作方)

Shawn 說「繼續」或類似指令時:

1. 讀 `docs/agent-sync/TASKS.md` —— 這是你的工作清單
2. 讀 `docs/agent-sync/QUESTIONS.md` —— 看有沒有你之前的提問已被回覆
3. 讀 `docs/SPEC.md` 中 TASKS 指到的章節
4. 動工
5. 完成後更新 `docs/agent-sync/PROGRESS.md`
6. **停下來等 review**,不要自行往下做 TASKS 沒指派的項目

### 如果你是老大(規格方)

Shawn 說「老二好了」或類似指令時:

1. 讀 `docs/agent-sync/PROGRESS.md` —— 看他做了什麼
2. 讀 `docs/agent-sync/QUESTIONS.md` —— 看有沒有新的 `[未回答]` 問題
3. 實際讀他改動的 code 做 review,不要只看他的自述
4. 需要 Shawn 決策的事,**先問 Shawn,不要自己決定產品方向**
5. 定案後更新 `docs/SPEC.md` 和 `docs/agent-sync/TASKS.md`

---

## 絕對不要做的事

1. **不要修改 `lib/logic/scheduler.dart` 裡 `reviewCard()` 的演算法內容。**
   那是已驗證的 SM-2,改了會壞掉。只能新增,不能改它的計算邏輯。
2. **不要修改 `test/scheduler_test.dart`** 或裡面的斷言。
3. **不要把 API key 寫死在任何 `.dart` 檔案裡。**
4. **不要引入 SPEC 沒提到的第三方套件。** 覺得非用不可就先在 `QUESTIONS.md` 提出。
5. **不要自行更動 UI 配色、字體、圓角等視覺樣式。** 視覺刻意保持陽春,之後才做美術。
6. **不要在 App 任何畫面出現「複習」兩個字。** Shawn 說那讓他感覺像在上課。
7. **不要顯示積壓數字、連續天數(streak)、完成率、正確率、任何評比。**
   這是刻意的產品決策,目的是消除罪惡感。

**不確定時的處理:** 停下來,在 `QUESTIONS.md` 寫清楚你卡在哪、有哪幾種可能的解讀、
你傾向哪個以及為什麼。不要猜。

---

## 產品設計原則

寫任何 UI 之前先理解這幾條,它們解釋了很多看似奇怪的規格:

1. **零壓力。** 沒有每日必須完成的配額,沒做完就往後延,不會有任何懲罰或提醒。
2. **負擔要輕。** 每天新字期望值約 4 個,穩定後每天 30–50 張,3–5 分鐘可完成。
3. **整潔俐落。** 整個 App 只有兩個主要畫面(首頁、學習畫面),不要增加層級。
4. **不要讓同一個字反覆糾纏。** 這是 Shawn 明確表達過的偏好,任何會提高
   答錯率的設計(例如中→英的產出方向測驗)都已被否決。
5. **排程訊號的品質最重要。** 四選一有亂猜風險,所以有「忘了」按鈕和反應時間
   自動分級來補救。任何會污染 quality 訊號的設計都要謹慎。

---

## 常用指令

```bash
# 改過 database.dart 後必跑,否則編譯失敗
dart run build_runner build --delete-conflicting-outputs

# 跑測試(必須全綠)
flutter test

# 本機開發
flutter run -d chrome
```

---

## Git 規則

- 一個獨立步驟一個 commit,不要累積一大包
- commit message 用英文,格式:`feat/fix/test/refactor: 簡短描述`
- 不要 force push,不要 rebase 已 push 的 commit
- 若 agent 環境沒有 GitHub 認證無法 push,在 `PROGRESS.md` 明確註明,由 Shawn 本機執行

---

## 上線前必辦(不在目前施工範圍)

`lib/services/ai_service.dart` 目前直接從 `.env` 讀 API key 在前端呼叫 AI。
正式部署時金鑰會暴露給所有使用者,必須改成經由自己的後端代理。
**不要刪掉該檔案裡的警告註解。**
