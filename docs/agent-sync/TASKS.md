# TASKS.md

> 老大(規格方)指派的工作順序。請由上往下做,做完一項就更新 `PROGRESS.md`。
> 有疑問寫進 `QUESTIONS.md`,標題用 `## [未回答] ...`,不要自己猜。

---

## 0. 【最優先】先 commit,再動任何 code

你目前所有變動都還沒進 git。這是好幾天的工作量,沒有版控保護,改壞就回不去了。

```
git add -A
git commit -m "feat: implement daily roll, web wasm db, quiz review screen, starter deck"
git push origin main
```

檔案已被我搬過位置(見第 1 項),這次 commit 會一併帶上搬移結果。

**做完這項才能往下。**

---

## 1. 檔案位置已變更(我已代為執行,你只需知悉)

為了避免專案根目錄變亂,溝通用文件全部收進 `docs/`:

```
docs/
├── SPEC.md                              ← 規格書(原本在 root)
└── agent-sync/
    ├── PROGRESS.md                      ← 你的工作日誌
    ├── QUESTIONS.md                     ← 你問、我答
    ├── TASKS.md                         ← 本檔案
    └── archive/
        └── IMPLEMENTATION_REPORT.md     ← 你先前的完整報告
```

專案根目錄現在只保留 `README.md`。

**規則:以後所有溝通文件一律寫在 `docs/agent-sync/` 底下,不要放在專案根目錄。**

如果你需要新的溝通檔案(例如想請我 review),建立 `docs/agent-sync/REVIEW_REQUEST.md`,
我會回在 `docs/agent-sync/REVIEW_NOTES.md`。

---

## 2. 複習畫面改成 v3 規格

`docs/SPEC.md` 的 6.3 與 6.4 已更新為 **v3 定案版**,請重讀那兩節。

**重點變更:**

- 先前我提的「依 `repetitions` 分流成四選一 / 回想模式」**已作廢**,不要實作
- 維持單一模式:四選一 + 獨立「忘了」按鈕
- 新增反應時間自動分級(Stopwatch)
- `lib/widgets/flashcard.dart` **刪除**
- `lib/widgets/question_card.dart` **新增**(不翻面的題目卡)
- 答題後要顯示 `exampleZh`
- distractor 選取改善:同 deck 優先 + `avoidWith` 排除近義詞

**注意:`lib/logic/scheduler.dart` 依然禁止改動。** 反應時間分級是在
`review_screen.dart` 決定 quality 值,不是改 SM-2 本身。

---

## 3. 內建牌組修正

`assets/decks/starter_deck.json`:

1. 改寫 `postpone` 與 `procrastinate` 的 `meaning`,增加區別度:
   - `postpone` → `延後(把預定時間往後挪)`
   - `procrastinate` → `拖延(該做卻遲遲不做)`
2. 幫這兩張卡互相加上 `avoidWith` 欄位:
   ```json
   { "word": "procrastinate", ..., "avoidWith": ["postpone"] }
   { "word": "postpone", ..., "avoidWith": ["procrastinate"] }
   ```
3. 其餘 28 個字我已 review 過,不需修改

---

## 4. 補測試

在 `test/` 新增反應時間分級的測試,至少涵蓋:

1. 按「忘了」→ quality 0
2. 選錯 → quality 0
3. 選對 2 秒 → quality 5
4. 選對 5 秒 → quality 4
5. 選對 12 秒 → quality 3
6. 邊界值:恰好 3 秒、恰好 8 秒(明確定義屬於哪一級並測試)

建議把分級邏輯抽成純函式(例如 `lib/logic/answer_grading.dart` 的
`int gradeAnswer({required bool isCorrect, required bool gaveUp, required Duration elapsed})`),
這樣才好測試,不用去測 UI。

`flutter test` 必須全綠,`test/scheduler_test.dart` 依然禁止修改。

---

## 5. 技術債記錄

在 `docs/agent-sync/PROGRESS.md` 開一個「技術債」區塊,寫入:

> **Web WASM 檔案來源非官方管道**
> `web/sqlite3.wasm` 目前取自本機 pub cache 的 drift devtools build,
> 非官方指定來源。實測功能正常,但 PWA 上線前必須換成官方 release 檔案並回歸測試。
> 官方來源:
> - `sqlite3.wasm` → https://github.com/simolus3/sqlite3.dart/releases
> - `drift_worker.dart.js` → https://github.com/simolus3/drift/releases
> 兩者需取同一 drift release 對應版本,混版會有難查的問題。

**現在不用處理,只要記錄。**

---

## 完成後

更新 `PROGRESS.md`,然後停下來等我 review。不要自行往下做 PWA manifest 或其他
SPEC 第 10 節的後續步驟。
