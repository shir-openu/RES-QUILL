# QA sweep 2026-08-31

Scope: pre-publish QA for the Flutter Res-Quill app. I did not push.
T34 update recorded on 2026-09-01 after the corrected sample files were resynced.

## Summary verdict

Ready for Shir to publish as a preview: YES.

The app code passes format verification, analysis, the full 105-test suite, the capture harness, the expanded sample UI harness, and the keyboard harness. The two previously blocking paste samples now reach generated reports in the real app with statistics that follow from their own descriptives. No remaining publish blocker was found in this sweep.

Expected non-report outcomes remain: the three refusal files refuse by design, and `spss_one_sample_p_is_000.txt` still stops at missing required descriptives while preserving the required `.000` to `p < .001` handling. That is not a preview blocker.

## Code changes made during sweep

| Area | Change |
| --- | --- |
| Light contrast | Darkened the light-mode cyan from `#087F8C` to `#077A86`; the worst active text contrast moved from 4.47:1 to 4.78:1. |
| Rounded SPSS output | Added narrow validation cushions for t/descriptives and CI checks so legitimate rounded SPSS display values do not block reports. |
| Validation badges | Changed related-only value cards from Error to Warning. `df = 48.80` is now Warning when df is only involved in a failing p/CI row; df is Error only when the df plausibility check itself fails. |
| Disabled report button | Added a screen-reader hint to the disabled Generate report button explaining the first blocking validation row. |
| Guide keyboard behavior | The guide now traps Tab focus inside the guide controls and Escape closes it. |
| Card focus | Removed duplicate keyboard stops from tappable cards while keeping the visible focus border. |
| Sample assets | Resynced the bundled paste assets from `SAMPLE_UPLOADS\PASTE_TEXT`; all seven source files now match byte-for-byte. |
| Intentional failing example | Added `assets/examples/paste_text/intentional_mistake_welch.txt` and the app button `Mistake: should fail`; validation blocks it by design. |

## Job 1: sample paste files through the real app

Harness: `flutter test tool/verify/qa_sweep_app_test.dart --reporter expanded`.
Parser comparison: `dart run tool/verify/claude_check_paste.dart`.
Raw harness output: `build/qa_sweep/app_samples.json`.

| File | App detection | User confirmation asked | Final app outcome and stats | Matches `claude_check_paste.dart` | Matches `EXPECTED_VALUES.md` | Defect |
| --- | --- | --- | --- | --- | --- | --- |
| `apa_sentence_welch.txt` | `needsConfirmation`; independent Welch; df `47.57`; p parsed as `0.014`; CI parsed as `[1.90, 16.10]`. | `Choose whether the p-value is one-tailed or two-tailed.` I chose Two-tailed. | Report generated. Final app stats: t `2.550819`, df `47.567979`, p `0.014022`, 95% CI `[1.904254, 16.095746]`, Cohen's d `0.713018`, Hedges' g `0.702039`. | YES | YES. Matches corrected `EXPECTED_VALUES.md`. | NO |
| `refuse_anova_table.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, out of scope. | NO |
| `refuse_empty.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, empty input refusal. | NO |
| `refuse_prose.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, no supported output shape. | NO |
| `spss_independent_samples.txt` | `needsConfirmation`; both SPSS variance rows detected; no selected kind until user chooses. Parsed Levene display values: F `0.179`, p `0.675`. | `SPSS has both rows. Choose the row your assignment uses.` Also missing CI confidence level. I chose Student because Levene's Sig. = `0.675` and used `.95` in typed fields. | Report generated. Student final app stats: t `2.415347`, df `38`, p `0.020638`, 95% CI `[1.743497, 19.799503]`, Cohen's d `0.763800`, Hedges' g `0.748608`. Additional app pass chose Welch and generated t `2.415347`, df `37.542856`, p `0.020700`, 95% CI `[1.739885, 19.803115]`. | YES | YES. Matches corrected `EXPECTED_VALUES.md`. | NO |
| `spss_one_sample.txt` | `confident`; one-sample t test. | None beyond reviewing detected values. | Report generated. Final app stats: t `3.068846`, df `30`, p `0.004529`, 95% CI `[0.468320, 2.331680]`, Cohen's d `0.551181`, Hedges' g `0.537266`. | YES | YES. Rounded display drift no longer blocks this ordinary SPSS output. | NO |
| `spss_one_sample_p_is_000.txt` | `needsConfirmation`; one-sample; p parsed as `< 0.001`, source `.000`. | Missing Group 1 n, Group 1 mean, Group 1 SD, and CI confidence level. | Blocked at missing required fields. Final stats: UNKNOWN. | YES | YES for the stated `.000` requirement. This file is not sufficient to generate a report. | NO |

Exact refusal text shown for the three refusal files:

| File | Exact refusal text |
| --- | --- |
| `refuse_anova_table.txt` | `ANOVA output is not supported.` |
| `refuse_empty.txt` | `Input is empty.` |
| `refuse_prose.txt` | `No supported t-test output shape was found.` |

Mismatches counted: 0.

Source-to-bundled asset sync was confirmed byte-for-byte by reading every source and destination file as bytes, comparing length and every byte position, and recording matching SHA-256 hashes for all seven source paste files.

## Job 2: light mode and 390px

Capture command: `flutter test --update-goldens tool/verify/capture_app_screens_test.dart`.
Final captures inspected: `captures/desktop_light_*.png`, `captures/desktop_light_guide_*.png`, `captures/phone390_light_*.png`, and `captures/phone390_light_guide_*.png`.

Contrast method: measured app foreground/background color pairs after compositing the relevant light-mode surfaces. Active guide/background text under the modal scrim was not counted as active text; guide bubble text was counted.

| Screen | Worst active text contrast, desktop light | Worst active text contrast, 390px light | Worst guide-open active text contrast | 390px clipping, overlap, or off-screen controls |
| --- | ---: | ---: | ---: | --- |
| Start | 5.08:1, primary button text | 5.08:1, primary button text | 5.08:1, NEXT TIP text | None. Content below the viewport scrolls normally. |
| Selection | 4.78:1, page kicker text | 4.78:1, page kicker text | 5.08:1, NEXT TIP text | None. Test cards stack cleanly. |
| Input | 4.78:1, page kicker text | 4.78:1, page kicker text | 5.08:1, NEXT TIP text | None. Paste box and review controls remain usable. |
| Validation | 4.78:1, page kicker text | 4.78:1, page kicker text | 5.08:1, NEXT TIP text | None. Generate report is partly below first viewport but reachable by scroll. |
| Report | 4.78:1, page kicker text | 4.78:1, page kicker text | 5.08:1, NEXT TIP text | None. Report cards scroll normally. |

Additional color checks:

| Item | Measured ratio | Result |
| --- | ---: | --- |
| Light cyan page kicker on page background | 4.78:1 | Meets 4.5:1 after fix. |
| White primary button text on light cyan | 5.08:1 | Meets 4.5:1. |
| Disabled button/card muted text on white | 5.41:1 minimum | Meets 4.5:1. |
| Error token against pale error wash | 5.64:1 | Reads as error on pale background. |
| Warning token against pale warning wash | 4.51:1 | Reads as warning on pale background. |
| Text inside error/warning notices | 12.55:1 to 13.56:1 | Meets 4.5:1. |

Disabled "Later" cards in light mode: clearly non-interactive. They use muted copy, reduced accent wash, no tap action, and semantics `enabled: false`; the light-mode test confirms tapping them stays on the start screen.

Guide box on phone: the guide bubble did not overlap the highlighted target region in the 390px captures. On very tall cards, non-highlighted continuation of the same card can remain dimmed behind the overlay, but the described highlighted region is not covered.

Sentences read from final captures:

| Capture | Sentence read |
| --- | --- |
| Light mode | `The sample data provided statistical evidence that the mean for Retrieval practice was higher than the mean for Restudy.` |
| 390px | `Retrieval practice had a mean of 81.40 (SD = 5.54, n = 20), and Restudy had a mean of 72.40 (SD = 9.26, n = 31).` |

390px problems found: 0. Fixed: 0.

## Job 3: keyboard and screen reader

Harness: `flutter test tool/verify/qa_keyboard_test.dart --reporter expanded`.
Raw tab-order output: `build/qa_sweep/keyboard.json`.

Condensed tab order:

| Screen | Tab order observed |
| --- | --- |
| Start | GUIDE, BRIGHT VIEW, SETTINGS, t tests card, Paste output, Type values, Try an example. Disabled Later cards are skipped. |
| Selection | GUIDE, BRIGHT VIEW, SETTINGS, Back to start, Student card, Student guide, Welch card, Welch guide, Paired card, Paired guide, One sample card, One sample guide. |
| Input | Back to start, paste-card guide, structured-fields guide, example buttons, CSV/Excel help buttons, paste text field, test-type dropdown, typed value fields, p-direction dropdown, top controls, Review output, row-choice radios, Show all found values, remaining typed fields. |
| Validation | GUIDE, BRIGHT VIEW, SETTINGS, Back to input, validation-summary guide, validation-decisions guide, Edit values, Show all checks. Disabled Generate report is not tabbable. |
| Report | GUIDE, BRIGHT VIEW, SETTINGS, Back to validation, report-prose guide, CI-chart guide, Copy report, Edit values, distribution guide, Show sources. |
| Guide open | SKIP, NEXT TIP. BACK is disabled on the first tip and is skipped. Focus stays inside the guide. Escape closes the guide. |

Screen-reader checks:

| Requirement | Result |
| --- | --- |
| Focus always visible | YES. Material controls show focus treatment; tappable cards draw a cyan focus border. Duplicate card stops were removed. |
| Guide traps focus | YES. The guide uses its own focus scope; repeated Tab stayed inside `Guide overlay focus scope`. |
| Escape closes guide | YES. Verified from the start guide. |
| Disabled Later cards announced disabled | YES. Semantics label includes the card text and status; semantics has enabled state false. |
| Disabled Generate report announces why | YES. It exposes a disabled hint such as `Disabled because validation failed: Reported t matches the descriptive statistics. Fix failed rows before generating a report.` |

Unresolved keyboard issues: 0.

## Job 4: df badge decision

Decision: changed.

Reason: df should be marked Error only when the df plausibility row fails. When df is merely an input to a failing p or CI row, the df card is now Warning with the text `Used in failing row: ...`. This prevents pushing a student to edit a correct df value.

The same related-only treatment was applied to t when it is only involved in a p-check failure; p remains Error for `Reported p matches t and df` because that row is primarily the p validation row.

## Proof commands

| Command | Result |
| --- | --- |
| `dart format --set-exit-if-changed lib test tool` after prepending `C:\flutter\bin` to PATH | PASS, 32 files checked / 0 changed. |
| `flutter analyze` after prepending `C:\flutter\bin` to PATH | PASS, no issues found. |
| `flutter test --reporter expanded` after prepending `C:\flutter\bin` to PATH | PASS, 105 pass / 0 fail. |
| `dart run tool\verify\claude_check_paste.dart` after prepending `C:\flutter\bin` to PATH | PASS, all seven source samples parsed/refused as recorded above. |
| `flutter test tool\verify\qa_sweep_app_test.dart --reporter expanded` after prepending `C:\flutter\bin` to PATH | PASS, seven source samples driven through the app plus a separate SPSS Welch-row report pass. |
| `flutter test tool\verify\qa_keyboard_test.dart --reporter expanded` after prepending `C:\flutter\bin` to PATH | PASS, tab order and guide behavior recorded. |
| `flutter test --update-goldens tool\verify\capture_app_screens_test.dart --reporter expanded` after prepending `C:\flutter\bin` to PATH | PASS, final captures recut; input captures changed because the SPSS sample values changed. |

## Blocking items before preview publish

None found in this T34 rerun.

The two previous blockers are cleared. `spss_independent_samples.txt` and `apa_sentence_welch.txt` now generate reports from the real app, and the newly added `Mistake: should fail` example is explicitly labelled and remains blocked by validation on purpose.

## CURRENT LIMITS

1. Res-Quill does not compute statistics from raw CSV or Excel rows.
2. Res-Quill supports only four t-test paths today: independent Student, independent Welch, paired samples, and one sample.
3. Res-Quill supports pasted SPSS, R `t.test()`, JASP, jamovi, Excel ToolPak, and APA-style t-test output; unsupported table/prose shapes are refused.
4. Base R `t.test()` output does not print sample N or SD, so R-only pastes can require the user to type missing descriptives before validation and report generation.
5. Bundled practice files are paste-text examples, not raw-data spreadsheets.
6. The desktop sample-folder button exports bundled paste-text examples to app data; web and Android hide it.
7. Res-Quill has no cloud storage.
8. Res-Quill has no accounts or sign-in.

App communication: the main statistical limits are stated on the start screen. The raw CSV/Excel boundary is also stated in the input help dialog and refusal message. Desktop practice uses exported paste-text examples only.

## UI STATE AS OF 2026-09-01

Reviewed by Claude from rendered captures, not from code inspection.

All five screens - start, selection, input, validation, report - were captured in both
themes at 1440x1000 and 390x900, twenty captures, and all twenty were opened and read.

Fixed on 2026-09-01:

1. The guide tip card occluded headings, controls or primary content on every screen. It is
   now placed by a single rule - a reserved dock with a clipped content viewport - rather
   than by per-screen special cases. Covered by a geometry test over 5 screens, 19 steps and
   2 widths.
2. The report screen's top navigation collided with the confidence interval chart labels.
3. Nine validation value-card strings named the check instead of its outcome, so a card
   could show an Error badge above a sentence reading "matches the descriptive statistics".
   Failing cards now state the outcome and the calculated value. Covered by a test that
   rejects an error or warning badge paired with an affirmative "matches" sentence.
4. Validation value cards were roughly three times taller than their content, which forced
   scrolling past near-empty boxes on mobile. They now fit their content.
5. Reported t and df are rounded in real output, which could falsely fail the p check near
   the .05 boundary. Validation tolerance now accounts for the rounding of the reported
   inputs.

Checked and found clean: no developer-facing identifiers on screen, no raw float noise, no
pale-on-pale text in BRIGHT VIEW.

Report wording was checked against four independently computed cases, including a Welch
result at p = .051 with a confidence interval that includes zero. The prose does not use
"marginally significant", "approaching significance" or "trend towards", reports p = .051
rather than .05, and states that the interval includes zero in agreement with the p value.
No change was made to the report prose.

Not verified: the Android APK has never been run. There is no Android device or emulator on
this machine, so its runtime behaviour is UNKNOWN rather than working or broken. The Windows
and web builds have both been launched and used.
