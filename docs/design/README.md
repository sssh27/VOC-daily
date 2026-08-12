# 設計稿

Stitch AI 產出、Shawn 於 v10 確認的畫面設計稿。

| 檔案 | 畫面 |
|---|---|
| `01-home-ready-to-start.png` | 首頁,已轉過拉霸 |
| `02-home-not-yet-spun.png`   | 首頁,還沒轉拉霸 |
| `03-study-intro-card.png`    | 學習,新字介紹卡 |
| `04-study-quiz.png`          | 學習,四選一題目 |
| `05-study-complete.png`      | 學習,今日完成 |
| `06-library.png`             | 牌組列表 |
| `07-settings.png`            | 設定 |
| `08-onboarding-slide-a.png`  | 首次啟動導覽 |
| `09-design-system.png`       | 色票與字型總覽 |

## 這些圖怎麼用

**當視覺參考,不是實作規格。** 有衝突時一律以 `docs/SPEC.md` 第 14、15 節為準。

已知設計稿與 SPEC 不一致之處(SPEC 15.4 有完整說明):

1. **首頁**:設計稿沒有背景金屬珍珠,實際要加(SPEC 第 14 節)
2. **Library**:設計稿的「MODULE 01/02/03」和牌組名稱是 Stitch 編的,不是真的;
   底部的「GENERATE WITH AI」按鈕要拿掉
3. **學習完成**:設計稿靠上對齊、下方大片空白,實際要垂直置中

另外設計稿裡的金屬球,已經去背處理成 `assets/images/pearl.png` 系列可直接使用。
