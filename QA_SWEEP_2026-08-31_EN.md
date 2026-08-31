# QA sweep 2026-08-31

Scope: pre-publish QA for the Flutter Res-Quill app. I did not push.

## Summary verdict

Ready for Shir to publish as a preview: NO.

The app code now passes format, analysis, the full 104-test suite, the capture harness, the sample UI harness, and the keyboard harness. The remaining blocker is content/data: two bundled/sample paste texts are internally inconsistent and therefore block report generation in the real app. They should either be corrected or deliberately relabeled as failing validation examples before publishing.

## Code changes made during sweep

| Area | Change |
| --- | --- |
| Light contrast | Darkened the light-mode cyan from `#087F8C` to `#077A86`; the worst active text contrast moved from 4.47:1 to 4.78:1. |
| Rounded SPSS output | Added narrow validation cushions for t/descriptives and CI checks so legitimate rounded SPSS display values do not block reports. |
| Validation badges | Changed related-only value cards from Error to Warning. `df = 48.80` is now Warning when df is only involved in a failing p/CI row; df is Error only when the df plausibility check itself fails. |
| Disabled report button | Added a screen-reader hint to the disabled Generate report button explaining the first blocking validation row. |
| Guide keyboard behavior | The guide now traps Tab focus inside the guide controls and Escape closes it. |
| Card focus | Removed duplicate keyboard stops from tappable cards while keeping the visible focus border. |

## Job 1: sample paste files through the real app

Harness: `flutter test tool/verify/qa_sweep_app_test.dart --reporter expanded`.
Parser comparison: `dart run tool/verify/claude_check_paste.dart`.
Raw harness output: `build/qa_sweep/app_samples.json`.

| File | App detection | User confirmation asked | Final app outcome and stats | Matches `claude_check_paste.dart` | Matches `EXPECTED_VALUES.md` | Defect |
| --- | --- | --- | --- | --- | --- | --- |
| `apa_sentence_welch.txt` | `needsConfirmation`; independent Welch; df `48.80` survived; p parsed as `< 0.001`. | `Choose whether the p-value is one-tailed or two-tailed.` I chose Two-tailed. | Report blocked by validation. Recomputed from displayed descriptives: t `2.550819`, df `47.567979`, p `0.014022`, 95% CI `[1.904254, 16.095746]`, Cohen's d `0.713018`, Hedges' g `0.702039`. | YES | Parser expectation is met, but the pasted sentence is internally inconsistent with its own descriptives. | YES |
| `refuse_anova_table.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, out of scope. | NO |
| `refuse_empty.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, empty input refusal. | NO |
| `refuse_prose.txt` | `cannotParse`; no t-test candidate. | None. | Refused. Final stats: UNKNOWN. | YES | YES, no supported output shape. | NO |
| `spss_independent_samples.txt` | `needsConfirmation`; both SPSS variance rows detected; no selected kind until user chooses. | `SPSS has both rows. Choose the row your assignment uses.` Also missing CI confidence level. I chose Student because Levene's Sig. = `0.525` and used `.95` in typed fields. | Report blocked by validation. Recomputed Student result from displayed descriptives: t `2.415347`, df `38`, p `0.020638`, 95% CI `[1.743497, 19.799503]`, Cohen's d `0.763800`, Hedges' g `0.748608`. | YES | It asks as expected, but reported t `2.245` conflicts with the expected/descriptive values. | YES |
| `spss_one_sample.txt` | `confident`; one-sample t test. | None beyond reviewing detected values. | Report generated. Final app stats: t `3.068846`, df `30`, p `0.004529`, 95% CI `[0.468320, 2.331680]`, Cohen's d `0.551181`, Hedges' g `0.537266`. | YES | YES. Rounded display drift no longer blocks this ordinary SPSS output. | NO |
| `spss_one_sample_p_is_000.txt` | `needsConfirmation`; one-sample; p parsed as `< 0.001`, source `.000`. | Missing Group 1 n, Group 1 mean, Group 1 SD, and CI confidence level. | Blocked at missing required fields. Final stats: UNKNOWN. | YES | YES for the stated `.000` requirement. This file is not sufficient to generate a report. | NO |

Exact refusal text shown for the three refusal files:

| File | Exact refusal text |
| --- | --- |
| `refuse_anova_table.txt` | `ANOVA output is not supported.` |
| `refuse_empty.txt` | `Input is empty.` |
| `refuse_prose.txt` | `No supported t-test output shape was found.` |

Mismatches counted: 2.

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
| `C:\flutter\bin\dart.bat format lib\src\app\res_quill_app.dart lib\src\app\res_quill_guide.dart lib\src\stats\validation.dart test\app\res_quill_app_test.dart tool\verify\qa_sweep_app_test.dart tool\verify\qa_keyboard_test.dart` | PASS |
| `C:\flutter\bin\flutter.bat analyze` | PASS, no issues found. |
| `C:\flutter\bin\flutter.bat test` | PASS, 104 pass / 0 fail. |
| `C:\flutter\bin\dart.bat run tool\verify\claude_check_paste.dart` | PASS, all seven samples parsed/refused as recorded above. |
| `C:\flutter\bin\flutter.bat test tool\verify\qa_sweep_app_test.dart --reporter expanded` | PASS, 7 samples driven through the app. |
| `C:\flutter\bin\flutter.bat test tool\verify\qa_keyboard_test.dart --reporter expanded` | PASS, tab order and guide behavior recorded. |
| `C:\flutter\bin\flutter.bat test --update-goldens tool\verify\capture_app_screens_test.dart` | PASS, final captures recut with font harness. |

## Blocking items before preview publish

1. Correct or intentionally relabel `spss_independent_samples.txt`. Its displayed descriptives recompute to Student t `2.415347`, not the reported t `2.245`; the real app blocks the report.
2. Correct or intentionally relabel `apa_sentence_welch.txt`. Its displayed descriptives recompute to t `2.550819` and df `47.567979`, not the reported t `4.34` and df `48.80`; the real app blocks the report.
3. The bundled app assets mirror those two sample texts, so this is not only an external QA corpus issue.

If those two files are meant to be failing examples, the UI/sample labels should say that explicitly before publishing. If they are meant to be happy-path examples, they need corrected values.
