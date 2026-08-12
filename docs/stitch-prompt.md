# VOC-daily — Stitch Prompt (All English UI)

> 分四批餵。**每一批都要把 `GLOBAL STYLE` 整段放在最前面。**

---

## GLOBAL STYLE — 每批都要貼這段

```
App: "VOC-daily", a minimal English vocabulary flashcard app.
Mobile only, portrait. All interface text in English.

=== GLOBAL STYLE — APPLIES TO EVERY SCREEN, DO NOT DEVIATE ===

CORE DESIGN LANGUAGE — FLUIDITY.
Everything in this app should feel like it is made of slowly moving
liquid. Surfaces are never flat or matte. Edges are never hard or
mechanical. Light bends and drifts across every surface. The overall
impression is of looking at oil on water, or the skin of a soap bubble
caught in slow motion.

VISUAL LANGUAGE — Y2K liquid chrome, restrained:
- Palette: pale silver-white base (#F0EEF5), lavender mist (#E3E1EC),
  chrome grey ramp (#BCC0D2 to #5F6478), deep ink text (#22243A).
- Iridescent accents used ONLY as light behind or across objects,
  never as fill on body text: soft violet #C9B8EE, periwinkle #A3B8EC,
  mint #A9DED2, pale pink #F0C2DE.

THE HERO OBJECT — a liquid soap bubble made of chrome:
- A large sphere that reads as both polished liquid metal AND a
  fragile soap bubble.
- Its surface carries a swirling oil-slick film: marbled iridescent
  bands of violet, periwinkle, mint and pale pink that flow across the
  curvature like petrol on water. Soft edged and organic, never
  symmetrical, never striped.
- Thin-film interference: iridescence is most saturated near the rim
  and nearly transparent at the centre, because the film is thickest
  when seen edge-on.
- A bright specular highlight upper left, a soft internal reflection
  lower right.
- A gentle iridescent halo bleeds outward behind it.

BACKGROUND — must not be flat or empty:
- A soft liquid marbling of silver, lavender and pale blue, like ink
  slowly diffusing in water or a very out-of-focus oil slick.
- Atmospheric depth: a few small blurred chrome bubbles drifting far
  in the background at low opacity, and faint caustic light ripples
  like sunlight through water.
- All background detail is heavily blurred and low contrast so it
  never competes with foreground text.

SURFACES:
- Cards are frosted translucent white with a 1px bright inner edge and
  a very soft ambient shadow. Rounded corners 20-24px. A faint
  iridescent sheen drifts across the frosted surface.
- Buttons are pill shaped with liquid, slightly organic edges. Primary
  button is a dark chrome gradient with a bright liquid top highlight
  and white bold text.

TYPOGRAPHY:
- Bold geometric sans throughout. Display numbers are large and heavy.
- Small labels are uppercase with wide letter spacing.
- ALL body text must be SOLID high-contrast dark colour. NEVER apply
  chrome, gradient, or iridescent fills to body text — only to large
  display numbers and screen titles.

TONE RULES — product decisions, obey strictly:
- NEVER show streaks, hearts, lives, leaderboards, XP, levels,
  accuracy percentages, completion rates, or any score.
- NEVER show a backlog or overdue count.
- The ONLY progress number allowed is "You know N words".
- Copy is calm and short. No urgency, no reminders to come back.
- Never use the word "review" anywhere. Use "study".
```

---

## 批次 1 — 首頁五種狀態

```
=== SCREENS ===

SCREEN 1 — HOME, NOT YET SPUN
- Top bar: left "VOC · DAILY" in small letter-spaced caps.
  Right: a hamburger icon.
- Center: the hero liquid chrome bubble, about 180px, halo behind it.
  Inside the bubble: a slot-machine icon and the label "SPIN".
  The bubble looks tappable.
- Below the bubble: small grey line "You know 87 words".
- Bottom: a wide pill primary button "START", dimmed/disabled.
- Nothing else. No stats, no cards, no bottom navigation bar.

SCREEN 2 — HOME, SPINNING
Same layout. The bubble is stretched and wobbling from the spin, its
oil-slick bands smeared into motion streaks. Inside, a large
chrome-gradient number mid-cycle. Halo brighter. "START" stays dimmed.

SCREEN 3 — HOME, ALREADY SPUN
Same layout. Inside the bubble: a large chrome number "4" with a small
uppercase label under it reading "NEW TODAY". Below the bubble:
"You know 87 words". Bottom: pill primary button "START", enabled.

SCREEN 4 — HOME, JACKPOT
Same layout, but the bubble is mid-burst: it has broken into several
smaller liquid chrome droplets suspended around the centre, with
iridescent film fragments and tiny sparkles. Where the bubble was,
two short lines: "DAY OFF" and "No new words". Celebratory but calm —
no confetti, no exclamation marks.

SCREEN 5 — HOME, NOTHING TO DO
Same layout. Bubble shows "4" and "NEW TODAY". The "START" button is
disabled, and below it a small grey line reads "Nothing to study today".
```

---

## 批次 2 — 學習流程六個畫面

```
=== SCREENS ===

SCREEN 6 — STUDY, INTRO CARD (a brand-new word, no quiz)
- Top bar: left "STUDY", right an X close icon. Under it a thin
  progress bar, about 20% filled with an iridescent gradient.
- One large frosted card, centered, containing in this order:
  the word "procrastinate" (large, bold, dark)
  phonetic "/prəˈkræstɪneɪt/" (small, grey)
  a thin divider
  definition "to keep delaying something you should do" (medium, dark)
  example "I always procrastinate when I have a big project due."
  with the word "procrastinate" in bold
- Bottom: two side-by-side pill buttons of equal width —
  left "NEXT" (primary, dark chrome),
  right "I KNOW THIS" (secondary, outlined, lighter).

SCREEN 7 — STUDY, QUIZ UNANSWERED
- Same top bar and progress bar.
- A frosted card containing only:
  the word "procrastinate" (large, bold)
  phonetic "/prəˈkræstɪneɪt/" (small, grey)
  example sentence with "procrastinate" in bold.
  No definition shown yet.
- Below the card, four full-width option buttons stacked vertically,
  each a frosted rounded rectangle with dark bold text:
  "to keep delaying something you should do"
  "dependable and trustworthy"
  "to discuss in order to reach an agreement"
  "feeling awkward or ashamed"
- A thin divider, then a separate, visually distinct outlined/dashed
  pill button "FORGOT". It must look clearly different from the four
  options so it reads as "I don't know", not a fifth answer.

SCREEN 8 — STUDY, ANSWERED CORRECTLY
Same as Screen 7, but the correct option ("to keep delaying something
you should do") is filled soft mint green with dark green text and
slightly scaled up. The other three options are dimmed. Below the
options, the example sentence is repeated in full with the word
highlighted.

SCREEN 9 — STUDY, ANSWERED WRONG
Same as Screen 8, but additionally the option the user picked ("to
discuss in order to reach an agreement") is filled soft rose pink with
dark rose text, while the correct answer stays mint green.

SCREEN 10 — STUDY, SESSION COMPLETE
- Clean centered layout, no card.
- A short calm line, large: "Done for today"
- Below it, larger and prominent: "You know 91 words"
- Bottom: pill button "HOME".
- NO score, NO accuracy, NO time spent, NO "come back tomorrow".

SCREEN 11 — STUDY, MILESTONE REACHED
- A large liquid chrome bubble, centered, mid-burst into suspended
  droplets with a bright iridescent burst and small white sparkles.
- At the centre, a large chrome-gradient number "100".
- Below: heading "One hundred words", then "You know 100 words".
- Bottom: pill button "HOME".
```

---

## 批次 3 — 單字庫與生成

```
=== SCREENS ===

SCREEN 12 — WORD LIBRARY
Reached from the hamburger on Home. Secondary screen, not main flow.
- Top bar: back arrow, title "LIBRARY".
- A summary line at top: "You know 87 words".
- A vertical list of deck rows. Each row is a frosted card showing:
  deck name (bold, dark)
  a thin progress bar with an iridescent fill
  small grey text "43 / 166 learned"
  a chevron on the right.
  Decks: "Cruise & Travel", "Kitchen & Food", "Home & Cleaning",
  "Clothing & Shopping", "Transport & Directions",
  "Body & Symptoms", "Starter Words"
- Bottom: a full-width outlined pill button "+ GENERATE WITH AI".

SCREEN 13 — DECK DETAIL
- Top bar: back arrow, deck name "Cruise & Travel".
- A search field with placeholder "Search words".
- A list of compact word rows, each showing:
  the word (bold, dark) on the left,
  a short definition (grey) on the right,
  and a tiny state dot: filled chrome = learned, hollow = not started.
  Example rows: "embark", "gratuity", "shore excursion", "seasick",
  "fanny pack", "hang out".
- Rows separated by hairlines, not individual cards.

SCREEN 14 — AI GENERATE, INPUT
- Top bar: back arrow, title "GENERATE".
- A large text field with placeholder
  "What do you want to learn? e.g. Business English B2"
- A row of three selectable chips: "10" "20" "30",
  with "20" selected. A small grey label under them: "cards".
- Bottom: primary pill button "GENERATE".

SCREEN 15 — AI GENERATE, PREVIEW
- Top bar: back arrow, title "PREVIEW".
- A scrollable list of generated word rows: the word bold on the left,
  a short definition grey on the right.
- Bottom: two pill buttons side by side — "REGENERATE" (secondary,
  outlined) and "ADD TO LIBRARY" (primary, dark chrome).
```

---

## 批次 4 — 設定與導覽

```
=== SCREENS ===

SCREEN 16 — SETTINGS
- Top bar: back arrow, title "SETTINGS".
- Grouped rows in frosted cards:
  Group "APPEARANCE": a segmented control "Light / Dark / System"
  Group "REMINDER": a toggle "Daily reminder" and a time row "20:00"
  Group "DATA": rows "Export backup" and "Import backup", each with a
    chevron
  Group "ABOUT": a row "Version 1.0.0"
- Calm and plain. No illustrations.

SCREEN 17 — ONBOARDING, three horizontally paged slides
Slide A: a liquid chrome bubble illustration.
  Heading "Spin every day"
  Body "The wheel decides how many new words you learn today. Not you."
Slide B: a frosted card illustration.
  Heading "Say when you forgot"
  Body "Tap forgot and the word comes back sooner. Guessing helps
  no one."
Slide C: no illustration, just space.
  Heading "Unfinished is fine"
  Body "Anything you skip simply moves to another day. Nothing is
  ever lost."
Each slide has page dots and a bottom pill button
("NEXT" on A and B, "START" on C).
```

---

## 提醒

1. **每批都要貼 `GLOBAL STYLE`**,漏掉那批風格就會歪。
2. **先只跑批次 1**,風格對了再往下。不對就只改 `GLOBAL STYLE` 重跑。
3. Screen 13、16、17 目前 App 裡不存在,要實作是額外工作量。想先讓現有功能變好看的話,做到批次 3 的 Screen 12 就夠。
