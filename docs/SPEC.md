# VOC-daily 實作規格書

> 這份文件是給實作者(AI 或人)的完整施工說明。
> 所有規則以本文件為準。文件沒寫到的部分,先問,不要自己發明。

---

## 0. 給實作者的重要提醒

閱讀順序:先讀完整份文件,再開始改任何檔案。

**絕對不要做的事:**

1. 不要修改 `lib/logic/scheduler.dart` 裡 `reviewCard()` 函式的演算法內容。那是已驗證的 SM-2,改了會壞掉。你只能「新增」檔案或函式,不能改它的計算邏輯。
2. 不要把 API key 寫死在任何 `.dart` 檔案裡。
3. 不要刪除既有的 `test/scheduler_test.dart`,也不要修改裡面的斷言。
4. 不要引入規格書沒提到的第三方套件。如果你覺得非用不可,先停下來說明理由。
5. 不要自行更動 UI 配色、字體、圓角等視覺樣式。目前視覺刻意保持陽春,之後才做美術。

**不確定時的處理方式:** 停下來,寫清楚你卡在哪、有哪幾種可能的解讀,不要猜。

---

## 1. 專案背景

一個英文單字/片語背誦 App。

- **核心機制**:間隔重複(Spaced Repetition),用 SM-2 演算法排程,讓單字在快要忘記的時間點重新出現。
- **差異化**:每日新單字量不是固定值,而是由「拉霸」隨機決定,並且有防止使用者棄坑的自動保護機制。
- **內容來源**:內建預設牌組(手動整理的字表)+ AI 依主題生成(進階功能)。

### 使用者是誰

一個想輕鬆背單字、不想有壓力的自學者。設計上必須避免任何形式的「你今天欠了 87 張卡」這類罪惡感。

---

## 2. 技術限制

| 項目 | 內容 |
|---|---|
| 框架 | Flutter 3.44.8,Dart 3.12.2 |
| 目標平台 | **Web (PWA) 優先**。開發時用 `flutter run -d chrome` 測試。 |
| 開發環境 | Windows,無 Mac,**不需要考慮 iOS 原生打包** |
| 資料庫 | Drift (SQLite) |
| 狀態管理 | Riverpod |
| 專案位置 | `C:\Users\shawn\VOC-daily` |
| GitHub | `https://github.com/sssh27/VOC-daily` |

### 2.1 Web 平台的資料庫設定(重要,容易踩坑)

Drift 在 Web 上不能直接用 `NativeDatabase`,必須改用 WASM 版本。實作時必須:

1. 下載 `sqlite3.wasm` 與 `drift_worker.js`,放到專案的 `web/` 資料夾
2. 把 `lib/data/database.dart` 裡的 `_openConnection()` 改成依平台分流:
   - Web → `WasmDatabase.open(...)`
   - 其他 → 保留現有的 `NativeDatabase.createInBackground(...)`
3. 使用 `package:flutter/foundation.dart` 的 `kIsWeb` 判斷平台

如果這一步卡住,先讓 App 在非 Web 平台跑起來,並明確回報 Web 端的狀況,不要為了繞過問題而換掉 Drift。

---

## 3. 現有程式碼狀態

```
lib/
├── main.dart                      # App 進入點,已完成
├── logic/
│   └── scheduler.dart             # SM-2 演算法,已完成且有測試,禁止改動邏輯
├── data/
│   └── database.dart              # Drift schema,需要擴充(見第 4 節)
├── services/
│   └── ai_service.dart            # AI 生成,骨架已寫,需補完
├── screens/
│   ├── home_screen.dart           # 佔位版本,需重寫
│   ├── review_screen.dart         # 佔位版本,需重寫
│   └── generate_screen.dart       # 骨架已寫,需補完
└── widgets/
    └── flashcard.dart             # 佔位版本,需重寫
test/
└── scheduler_test.dart            # 已完成,禁止修改
```

### 3.1 現有的 SM-2 介面(照用,不要改)

```dart
class ScheduleState {
  final double easiness;    // 難易度係數,初始 2.5,最低 1.3
  final int interval;       // 距離下次複習的天數
  final int repetitions;    // 連續答對次數
  final DateTime dueDate;   // 下次該出現的日期
}

ScheduleState reviewCard(ScheduleState state, int quality, {DateTime? now});
// quality: 0=忘記了, 3=有點難, 4=普通, 5=簡單
```

---

## 4. 資料模型

### 4.1 Decks 表(牌組)— 已存在,不需改

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | int, PK, autoIncrement | |
| name | text | 牌組名稱,例:「多益商用英文 B2」 |
| topic | text, default '' | 生成時使用的主題描述 |
| createdAt | dateTime, default now | |

### 4.2 Cards 表(單字卡)— 需要新增 1 個欄位

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | int, PK, autoIncrement | |
| deckId | int, FK → Decks.id | |
| word | text | 單字或片語,例:`procrastinate` |
| phonetic | text, default '' | 音標,例:`/prəˈkræstɪneɪt/` |
| meaning | text | 中文解釋(繁體),例:`拖延` |
| example | text, default '' | 英文例句 |
| exampleZh | text, default '' | 例句中譯(繁體) |
| easiness | real, default 2.5 | SM-2 欄位 |
| interval | int, default 0 | SM-2 欄位 |
| repetitions | int, default 0 | SM-2 欄位 |
| dueDate | dateTime, default now | SM-2 欄位 |
| lastReviewed | dateTime, nullable | |
| **isIntroduced** | **bool, default false** | **【新增】是否已被拉霸放進學習循環** |

`isIntroduced` 的意義:

- 卡片剛被建立(AI 生成或匯入)時是 `false`,代表「在倉庫裡,還沒開始學」
- 拉霸決定今天要學 N 個新字時,從 `isIntroduced == false` 的卡片中挑 N 張,設成 `true` 並把 `dueDate` 設為今天
- 只有 `isIntroduced == true` 的卡片才會出現在複習流程裡

### 4.3 DailyRolls 表(每日拉霸紀錄)— 全新

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | int, PK, autoIncrement | |
| rollDate | dateTime, unique | 該次拉霸的日期,**只存年月日,時分秒歸零** |
| quota | int | 骰出的新字額度:0, 3, 4, 5, 或 6 |
| wasCapped | bool, default false | 是否因積壓而被自動下修 |

**規則:一天只能有一筆紀錄。** 判斷今天是否已拉過,就是查 `rollDate == 今天零點` 有沒有資料。

---

## 5. 核心邏輯規格

### 5.1 積壓量的定義

```
backlogCount = Cards 表中,符合以下全部條件的筆數:
  - isIntroduced == true
  - dueDate < 今天的 00:00:00
```

注意是「今天零點之前」,**不包含今天到期的卡**。今天該複習的不算積壓,只有前幾天沒做完的才算。

### 5.2 拉霸權重表

正常狀態(積壓 0–20 張)的機率分布:

| 骰出結果 | 權重 | 機率 | 意義 |
|---|---|---|---|
| 0 | 5 | 5% | **JACKPOT — 今天不用背新字,放假** |
| 3 | 30 | 30% | |
| 4 | 30 | 30% | |
| 5 | 25 | 25% | |
| 6 | 10 | 10% | |
| 合計 | 100 | 100% | 期望值 3.95 |

### 5.3 自動保護機制

積壓越多,骰子上限越低,避免使用者回來看到爆炸的數字而棄坑。

| 積壓量 | 上限 | 可能結果 | 說明 |
|---|---|---|---|
| 0–20 張 | 6 | 0, 3, 4, 5, 6 | 正常 |
| 21–50 張 | 4 | 0, 3, 4 | 下修,`wasCapped = true` |
| 51 張以上 | 0 | 只有 0 | 今天不給新字,先清舊帳,`wasCapped = true` |

被下修時,權重表要**只保留 ≤ 上限的選項,並重新正規化**(不是直接砍掉機率,而是剩下的選項按原比例放大)。

例:積壓 30 張時,可選 0(權重5)、3(權重30)、4(權重30),總權重 65,所以骰出 3 的機率是 30/65 ≈ 46%。

### 5.4 拉霸函式規格

新增檔案 `lib/logic/daily_roll.dart`:

```dart
import 'dart:math';

/// 拉霸結果
class RollResult {
  final int quota;       // 0, 3, 4, 5, 6
  final bool wasCapped;  // 是否因積壓被下修
  bool get isJackpot => quota == 0 && !wasCapped;  // 真正的中獎(非被下修導致的 0)

  const RollResult({required this.quota, required this.wasCapped});
}

/// 依積壓量骰出今日新字額度。
/// [backlogCount] 見 5.1 定義
/// [random] 可注入以便測試
RollResult rollNewCardQuota(int backlogCount, {Random? random}) {
  // 實作依 5.2 / 5.3
}
```

**重要:`isJackpot` 必須區分「真的中獎」和「被下修成 0」。** 兩者 quota 都是 0,但前者要放慶祝動畫,後者不能——被下修還放煙火會很怪。

### 5.5 引入新卡的流程

當使用者完成拉霸,得到 quota = N(N > 0)時:

1. 從 Cards 表撈出 `isIntroduced == false` 的卡片,最多 N 張
2. 對每一張:
   - `isIntroduced = true`
   - `dueDate = 今天的 00:00:00`
   - 其他 SM-2 欄位維持初始值(easiness 2.5, interval 0, repetitions 0)
3. 寫入 DailyRolls 表

如果倉庫裡沒有足夠的未引入卡片(例如骰到 5 但只剩 2 張),就引入所有剩下的,並在畫面上提示使用者「單字庫快用完了,去生成新的吧」。

### 5.6 複習佇列的組成

進入複習畫面時,要複習的卡片 = 符合以下條件的所有卡片,依 dueDate 由舊到新排序:

```
isIntroduced == true  AND  dueDate <= 今天的 23:59:59
```

這會同時包含「今天到期的」和「之前積壓的」,積壓的排前面。

### 5.7 沒做完怎麼辦

**什麼都不用做。** 沒複習的卡片 dueDate 不變,明天自然變成積壓,被 5.1 算進去,進而觸發 5.3 的保護機制降低新字量。

不要實作任何「未完成懲罰」、「連續天數中斷」、「進度條變紅」之類的機制。這是刻意的設計決定。

---

## 6. 畫面規格

### 6.1 首頁 `lib/screens/home_screen.dart`

**【v4 修訂】拉霸改成就地進行,獨立的拉霸畫面刪除。**

整個 App 的主畫面。設計原則:**極簡,一個轉盤 + 一個按鈕。**

```
┌──────────────────────────┐
│  VOC-daily          [☰]  │  ← ☰ 導向單字庫(6.5),平常不會點
│                          │
│       ╭─────────╮        │
│       │   🎰    │        │
│       │  轉一下  │        │
│       ╰─────────╯        │
│                          │
│        [ 開始 ]          │
└──────────────────────────┘
```

#### 轉盤區(就地互動,不跳頁)

| 狀態 | 顯示 | 可否點擊 |
|---|---|---|
| 今天還沒轉 | 🎰 + 「轉一下」 | 可點,點下去就地播動畫 |
| 轉動中 | 數字快速跳動,約 1.5 秒 | 不可點 |
| 已轉完(quota > 0) | 「今日新字:**4** 個」 | 不可點 |
| 已轉完(JACKPOT) | 「🎉 今天放假,沒有新字」+ 慶祝動畫 | 不可點 |
| 已轉完(被下修成 0) | 「今天先把之前的做完就好」**不放慶祝動畫** | 不可點 |

動畫結束後,執行 5.5 的引入新卡流程。

**動畫實作提示:** `AnimatedBuilder` + `Timer.periodic` 快速更換顯示數字即可,
不需要引入動畫套件。

#### 「開始」按鈕

導向 6.4 的學習畫面。

- 今天沒有任何要學的東西(新字 0 且無到期卡)→ 按鈕禁用,下方顯示「今天沒有要學的了」
- 其他情況一律可按

#### 嚴格禁止顯示的內容

- 積壓數字(「你已經欠了 N 張」)
- 連續學習天數 / streak
- 完成率、正確率、任何百分比
- **「複習」這兩個字**。使用者不需要知道佇列裡哪些是新字哪些是複習。

---

### 6.2 (已刪除)

**【v4】原本的獨立拉霸畫面 `lib/screens/daily_roll_screen.dart` 已廢止,請刪除該檔案。**

理由:首頁本來就有一個轉盤圖示,點下去卻跳到另一頁看第二個轉盤,是無意義的重複。
拉霸動畫改為在首頁就地播放(見 6.1)。

---

### 6.3 題目卡片元件 `lib/widgets/question_card.dart`

單面顯示,不可點擊翻面。

```
┌────────────────────────────┐
│      procrastinate         │  ← word,大字
│    /prəˈkræstɪneɪt/        │  ← phonetic,小字灰色
│                            │
│  I always **procrastinate**│  ← example,目標單字粗體
│  when I have a big         │
│  project due.              │
└────────────────────────────┘
```

**粗體規則:** 在 `example` 字串中,把 `word` 出現的地方套用 `FontWeight.bold`。

- 大小寫不敏感比對
- 單一詞時允許詞形變化(word=`procrastinate`,句中 `procrastinating` 也要粗體)
- 找不到就整句原樣顯示,不要報錯

**不做挖空。** 目標單字已顯示在上方,挖空沒有意義。

**元件介面:**

```dart
class QuestionCard extends StatelessWidget {
  final String word;
  final String phonetic;
  final String example;
}
```

---

### 6.3b 認識卡元件 `lib/widgets/intro_card.dart`(v4 新增)

新字第一次出現時使用。**只給看,不考。**

理由:第一次見到的字直接考四選一是不合理的,使用者只能亂猜,產生的 quality 訊號是雜訊。

```
┌────────────────────────────┐
│      procrastinate         │
│    /prəˈkræstɪneɪt/        │
│                            │
│   拖延(該做卻遲遲不做)     │  ← meaning
│  ────────────────────      │
│  I always procrastinate    │  ← example(單字粗體)
│  when I have a big         │
│  project due.              │
│                            │
│  每次有大專案要交,          │  ← exampleZh
│  我總是拖延。               │
└────────────────────────────┘
```

**元件介面:**

```dart
class IntroCard extends StatelessWidget {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String exampleZh;
}
```

按鈕(「下一個」)由學習畫面負責,不是這個元件的責任。

---

### 6.4 學習畫面 `lib/screens/review_screen.dart`

**【v4 修訂】新字與到期字合併成單一連續流程。畫面上不得出現「複習」字樣。**

檔名維持 `review_screen.dart` 不變(避免大量 import 改動),但畫面標題改為
**「學習」**,class 名稱改為 `StudyScreen`。

#### 佇列組成與順序

進入畫面時,依序組出一條佇列:

| 順位 | 內容 | 篩選條件 | 排序 |
|---|---|---|---|
| 1 | **新字** | `isIntroduced == true` 且 `lastReviewed == null` | 依 id 由小到大 |
| 2 | **到期字** | `isIntroduced == true` 且 `lastReviewed != null` 且 `dueDate <= 今天 23:59:59` | 依 `dueDate` 由舊到新 |

新字永遠排在最前面。使用者感受上就是一條連續的流程,不需要知道分界在哪。

#### 模式 A:新字 →「認識卡」(不考)

用 6.3b 的 `IntroCard`,底部只有一個「下一個」按鈕。

按下「下一個」時:

```dart
final newState = reviewCard(currentState, 4);  // quality 固定 4
```

**為什麼用 quality 4:** 代入 SM-2 後 `repetitions == 0` → `interval = 1`,
`easiness` 剛好維持 2.5 不變,`dueDate` 變成明天。這正是「今天認識過,明天開始考」
的期望結果,而且完全不繞過 `scheduler.dart`。

寫回資料庫(含 `lastReviewed = now`)後前進到下一張。

**新字今天只出現這一次,不會在同一次流程裡被考。**

#### 模式 B:到期字 → 四選一測驗

```
┌────────────────────────────┐
│      procrastinate         │  ← QuestionCard (6.3)
│    /prəˈkræstɪneɪt/        │
│  I always **procrastinate**│
│  when I have a big         │
│  project due.              │
└────────────────────────────┘

   [  拖延(該做卻遲遲不做)  ]
   [  可靠的                ]     ← 四個中文意思選項,隨機排序
   [  談判;協商            ]
   [  尷尬的                ]

   ─────────────────
   [        忘了        ]     ← 獨立按鈕,視覺上與四選項分開
```

「忘了」必須在視覺上明顯與四個選項區隔(分隔線 + 不同樣式),
讓使用者清楚知道這不是第五個答案選項,而是「我不知道」的誠實回報。

##### 評分規則(quality 對應)

| 使用者行為 | quality |
|---|---|
| 按「忘了」 | **0** |
| 選錯 | **0** |
| 選對,**3 秒內** | **5** |
| 選對,**3–8 秒** | **4** |
| 選對,**超過 8 秒** | **3** |

邊界值:恰好 3 秒 → 5;恰好 8 秒 → 4。

##### 計時規格

- 使用 `Stopwatch`
- **開始計時:** 該題的選項建立完成、畫面 render 之後立刻開始
- **停止計時:** 使用者第一次點擊任何按鈕(含「忘了」)的瞬間
- 每題獨立計時,切換題目時重置
- 不需要處理「使用者切走再切回來」的情況(時間會很長 → 判 quality 3,是合理的保守結果)

##### 答題後的回饋

1. 鎖定所有按鈕,不可再點
2. 正確答案標綠;若選錯,使用者選的那個標紅
3. 顯示 `exampleZh`
4. 停留後自動跳下一題:
   - **答對** → 1.4 秒
   - **答錯或按「忘了」** → **3 秒**(答錯時需要更多時間看清楚正確答案)

##### 干擾項(distractor)選取規則

依序嘗試,取滿 3 個為止:

1. **優先從同一個 deck** 的其他卡片挑 `meaning`
2. **排除 `avoidWith` 標記的字**(雙向:這張卡列了對方,或對方列了這張卡)
3. 同 deck 湊不滿 3 個時,回退到全庫隨機

**【v4 新增】選項不足時的處理:**

| 可取得的 distractor 數 | 行為 |
|---|---|
| 3 個 | 正常四選一 |
| 1–2 個 | 顯示 2–3 個選項(仍含「忘了」按鈕),照常計分 |
| 0 個 | **改用模式 A 的認識卡顯示**(無法出題),按「下一個」以 quality 4 計 |

#### 【v4 新增】答錯補考機制

答錯或按「忘了」的卡片,**排到本次流程的最後補考一次**。

規則:

1. 每張卡在一次流程中**最多只補考一次**。補考時再答錯,不再重複排入。
2. **補考的結果不寫回資料庫。** SM-2 的排程已經在第一次作答時決定好了
   (quality 0 → interval 重設為 1 天),補考純粹是趁記憶還熱時的即時補強,
   不應該讓使用者靠補考「洗掉」原本的失敗紀錄。
3. 補考題的呈現與一般題目完全相同,不要標示「這是補考」。
4. 新字的認識卡不會產生補考(沒有答錯的可能)。

實作提示:用一個 `List<Card> _retryQueue` 蒐集待補考的卡,主佇列跑完後接上去,
並用一個 `Set<int> _alreadyRetried` 記錄已補考過的卡 id 避免無限循環。

#### 完成畫面

「今天做完了」+ 返回首頁按鈕。

**不要顯示分數、正確率、答對幾題、或任何評比。**

#### 中途離開

允許隨時返回首頁。已作答的卡片保留結果,未作答的維持原狀
(明天會變積壓,由 5.3 的保護機制處理)。

---

### 6.5 單字庫 `lib/screens/decks_screen.dart`

**【v4 修訂】原「牌組列表」降級為次要畫面,改名「單字庫」。**

從首頁右上角的 ☰ 進入,不是主流程的一部分。

用途只有兩個:看看庫存、管理 AI 生成的批次。

```
單字庫

入門常用字
已學 43 / 120

多益商用英文 B2
已學 8 / 20

[ + AI 生成新單字 ]
```

- 「已學」= 該牌組中 `isIntroduced == true` 的卡片數
- 分母 = 該牌組總卡片數
- 進度條可留可不留,不強制

**牌組(Deck)這個概念為什麼保留:** 雖然使用者平常看不到,但它在資料層有兩個實際用途:

1. AI 一次生成一批卡片,需要一個容器才能後續管理或整批刪除
2. 四選一的干擾選項優先從同一牌組挑選,同主題的字語意距離接近,才有鑑別度。
   沒有牌組分組就只能全庫亂抽,會產生用刪去法就能過的送分題。

---

### 6.6 AI 生成畫面 `lib/screens/generate_screen.dart`(補完現有骨架)

1. 輸入框:主題描述(例:「多益商用英文 B2 程度」)
2. 數量選擇:10 / 20 / 30 張
3. 「生成」按鈕 → 呼叫 `AiService.generateCards()`
4. loading 狀態顯示轉圈,按鈕禁用
5. 生成成功 → 顯示預覽列表(word + meaning)
6. 預覽下方兩個按鈕:
   - 「重新生成」→ 重跑
   - 「加入牌組」→ 建立新 Deck,把卡片寫入,`isIntroduced` 全部為 `false`
7. 錯誤處理:
   - 沒有 API key → 「尚未設定 API 金鑰」
   - 網路錯誤 → 「連線失敗,請檢查網路」
   - JSON 解析失敗 → 「AI 回傳格式異常,請再試一次」

**重要:生成的卡片一律 `isIntroduced = false`。** 它們進倉庫等待,由拉霸決定何時進入學習循環。不要生成完就直接開始學。

---

## 7. 預設牌組(內建內容)

App 第一次啟動時,如果資料庫是空的,要自動匯入一份內建牌組,讓使用者不需要設定 API key 就能開始用。

1. 在 `assets/decks/` 放一個 `starter_deck.json`
2. 格式:

```json
{
  "name": "入門常用字",
  "topic": "日常英文高頻字彙",
  "cards": [
    {
      "word": "procrastinate",
      "phonetic": "/prəˈkræstɪneɪt/",
      "meaning": "拖延",
      "example": "I always procrastinate when I have a big project due.",
      "exampleZh": "每次有大專案要交,我總是拖延。"
    }
  ]
}
```

3. 在 `pubspec.yaml` 的 `assets` 區塊註冊這個路徑
4. 在 App 啟動時檢查 Decks 表是否為空,是的話才匯入(不要每次啟動都重複匯入)

**內容準備:** 先放 30 張即可,由專案擁有者提供或請實作者依「日常英文高頻字彙」主題產出,但必須每張都有完整的 5 個欄位。

---

## 8. 檔案異動清單

| 檔案 | 動作 | 說明 |
|---|---|---|
| `lib/logic/scheduler.dart` | **不動** | SM-2,已驗證 |
| `lib/logic/daily_roll.dart` | 新增 | 拉霸邏輯,見 5.4 |
| `lib/data/database.dart` | 修改 | 加 `isIntroduced` 欄位、加 DailyRolls 表、Web WASM 設定 |
| `lib/data/card_repository.dart` | 新增 | 封裝所有資料庫查詢,畫面層不直接碰 Drift |
| `lib/services/ai_service.dart` | 修改 | 補完錯誤處理 |
| `lib/services/starter_deck_loader.dart` | 新增 | 首次啟動匯入內建牌組 |
| `lib/screens/home_screen.dart` | 重寫 | 見 6.1 |
| `lib/screens/daily_roll_screen.dart` | **刪除**(v4) | 拉霸改在首頁就地進行 |
| `lib/screens/review_screen.dart` | 重寫 | 見 6.4 |
| `lib/screens/decks_screen.dart` | 新增 | 見 6.5 |
| `lib/screens/generate_screen.dart` | 修改 | 見 6.6 |
| `lib/widgets/flashcard.dart` | **刪除** | 翻卡模式已否決 |
| `lib/widgets/question_card.dart` | 新增 | 見 6.3 |
| `lib/widgets/intro_card.dart` | 新增(v4) | 見 6.3b |
| `test/scheduler_test.dart` | **不動** | |
| `test/daily_roll_test.dart` | 新增 | 見第 9 節 |
| `assets/decks/starter_deck.json` | 新增 | 見第 7 節 |
| `pubspec.yaml` | 修改 | 註冊 assets 路徑 |

改完 `database.dart` 後必須執行:

```
dart run build_runner build --delete-conflicting-outputs
```

否則 `database.g.dart` 不會更新,編譯會失敗。

---

## 9. 驗收標準

### 9.1 必須通過的單元測試

新增 `test/daily_roll_test.dart`,至少涵蓋:

1. 積壓 0 張時,骰 10000 次,結果集合只包含 {0, 3, 4, 5, 6}
2. 積壓 0 張時,骰 10000 次,平均值落在 3.7 ~ 4.2 之間
3. 積壓 30 張時,骰 1000 次,結果不曾超過 4,且 `wasCapped == true`
4. 積壓 60 張時,骰 100 次,結果永遠是 0,且 `wasCapped == true`
5. 積壓 60 張骰出的 0,`isJackpot` 必須是 `false`
6. 積壓 0 張骰出的 0,`isJackpot` 必須是 `true`

執行 `flutter test`,既有的 `scheduler_test.dart` 也必須全部通過。

### 9.2 手動驗收流程

1. `flutter run -d chrome` 能成功啟動,不報錯
2. 首次啟動自動出現「入門常用字」牌組,且卡片數 > 0
3. 首頁顯示轉盤
4. 點轉盤 → **就地**播放滾動動畫 → 定格出數字(不跳頁)
5. 同一天重新整理頁面,不能再拉第二次
6. 引入的新卡數量與骰出的數字一致
7. 學習畫面:新字先出現「認識卡」(只有「下一個」按鈕),接著才是到期字的四選一
8. 四選一 + 獨立「忘了」按鈕;例句中的目標單字有粗體;答題後標示正確/錯誤並顯示例句中譯
9. 答錯的字會在流程最後再出現一次,且補考結果不影響排程
10. 全 App 任何畫面都看不到「複習」兩個字
11. 評分後卡片的 dueDate 有按 SM-2 更新
12. 關掉瀏覽器重開,資料還在(驗證 Drift Web 持久化正常)

### 9.3 需要人工確認的模糊地帶

實作到以下情況時,**停下來詢問**,不要自行決定:

- 例句挖空遇到片語(word 是多個單字)時的處理方式
- Drift Web WASM 設定若與現有 Drift 版本不相容
- 內建牌組的 30 個單字,若要由實作者產出,先把清單給專案擁有者確認再寫入

---

## 10. 開發順序建議

照這個順序做,每一步都可獨立驗證:

1. **資料層** — 改 schema、跑 build_runner、寫 `card_repository.dart`
2. **拉霸邏輯 + 測試** — 純函式,先讓 `flutter test` 綠燈
3. **內建牌組匯入** — 確認首次啟動有資料
4. **字卡元件** — 先寫死假資料驗證挖空與翻面正確
5. **複習畫面** — 串真資料 + SM-2 寫回
6. **拉霸畫面 + 首頁** — 串起完整每日流程
7. **牌組列表**
8. **AI 生成畫面補完**
9. **Web WASM 設定** — 讓資料在瀏覽器持久化
10. **PWA manifest 調整** — 圖示、名稱、可安裝到主畫面

前 8 步都可以在 `flutter run -d chrome` 下開發,第 9 步之前資料不會持久化是正常的。

---

## 11. 上線前必辦(不在本次施工範圍,但要留意)

`lib/services/ai_service.dart` 目前直接從 `.env` 讀 API key 並在前端呼叫 AI。這在正式部署時**金鑰會暴露給所有使用者**。

正式上線前必須把這段挪到後端(例如 Firebase Cloud Functions),前端只呼叫自己的 endpoint。

實作者這次不需要處理這件事,但**不要把現有的警告註解刪掉**。
