# Flutter App Report - 2026-08-31

## Student Walkthrough: First Five Blockers

Scenario: a psychology student has an SPSS t-test table, needs APA wording for an assignment, and does not trust herself to choose the right row or phrase the result correctly.

1. Where to start
   What they see: the app opens with three actions, paste output, type values, and try an example.
   What they think: "I have a table, not raw data. Which button is for me?"
   Smallest fix: make the first action say that SPSS, JASP, jamovi, or APA output belongs in the paste path, not the manual path.

2. Which SPSS row to use
   What they see: an independent-samples table can contain both "Equal variances assumed" and "Equal variances not assumed."
   What they think: "SPSS gave me two answers. I do not know if I am allowed to pick one."
   Smallest fix: show the row choice as the first detected decision and name it Student row versus Welch row, with a short Levene note.

3. What to do with Sig. and .000
   What they see: SPSS labels p-values as "Sig." or "Sig. (2-tailed)", and sometimes prints ".000."
   What they think: "Is .000 my p-value? Is this one-tailed or two-tailed?"
   Smallest fix: label the p-value direction next to the detected p field and render SPSS .000 as p < .001 before report generation.

4. Why the report is blocked
   What they see: validation can show several recomputed values and some failures.
   What they think: "The app says Fail, but I do not know which number I should change first."
   Smallest fix: put the failing checks first on narrow screens and state the exact entered value, recomputed value, and allowed rounding difference.

5. What can be pasted into the assignment
   What they see: the report screen gives APA wording, descriptives, meaning, effect size, supported claims, and unsupported claims.
   What they think: "Which sentence is safe to copy, and what should I avoid claiming?"
   Smallest fix: keep the copyable APA result prominent, keep unsupported causal or direction claims separate, and use student-facing labels rather than role labels.

## Next Run Fix Candidates

I can fix all five in the next run. The first three are the most direct student blockers: clarify the paste path, make the SPSS row choice unavoidable, and make p-value direction and .000 handling explicit. The fourth is partly fixed by placing problems first on 390px validation screens. The fifth is partly fixed by clearer report wording and can be strengthened by making supported and unsupported claims easier to review before copying.

## T30 Milestone 8: V6 Guide Port And Persistence

Source followed: ANIM_CODEX v6 prototype and design document from ONBOARDING, with no edits made there.

Guide port:
- The app now has one quiet guide entry per guided card, plus the top replay control.
- Visible guide button counts match v6: Start 1, Compare means/groups 5, Input/paste 3, Validation review 3, Report draft 4.
- Guide copy is the approved v6 guide copy, with the v6 total of 327 words.
- The start screen keeps the sequential walkthrough.
- Card guide buttons open one short box for the whole card.
- There is no auto-advance. The user clicks NEXT TIP.
- Keyboard support: Enter and right arrow move forward, left arrow moves back, Escape closes.
- First-entry blink runs three cycles only on the first visit to each screen. Reduced motion uses a strong static treatment during the same first-entry window.

Persistence:
- Storage is via the Flutter shared_preferences plugin.
- Logical keys: resquill.theme and resquill.guide.seenScreens.
- Web storage: browser localStorage, with the plugin prefix, for example flutter.resquill.theme.
- Windows storage: shared_preferences.json in the app support directory under RoamingAppData.
- Android storage: app-private FlutterSharedPreferences SharedPreferences.
- Restart persistence is covered by the widget test "guide seen state survives a restart".
- Platform confirmation run: web debug build passed, Windows debug build passed, Android debug APK build passed.
- Physical Android device runtime check: UNKNOWN.

Settings:
- Settings now contains replay guide, reset guide seen state, and the theme toggle.
- Replay starts the current screen guide without changing data.
- Reset clears seen screen state so the first-entry treatment can run again.

Update behavior:
- Seen state is screen-level and stable, not guide-versioned.
- If an update adds controls, users who saw the old screen guide are not silently forced through the whole tour again.
- New controls should get quiet card guide buttons. Users can open them directly, use Replay guide, or reset guide seen state from Settings.

Student blocker fixes included in the port:
- Paste path wording now explicitly starts from SPSS output or APA text.
- SPSS row choice is surfaced as Student row versus Welch row.
- The p field calls out SPSS .000 as p < .001.
- Alpha is labelled as the course level, not something guessed by the app.
- Welch df is labelled as allowed to be decimal.
- Report claims are visible without requiring a separate reveal.

Verification:
- dart format lib test tool: passed.
- flutter analyze: passed.
- flutter test: 100 passed, 0 failed.
- flutter test --update-goldens tool/verify/capture_app_screens_test.dart: passed.
- Captures regenerated: 40 total, covering desktop and 390px, light and dark, normal and guide-open states.
- Inspected all 20 guide-open captures. Fonts rendered and text was readable in both themes.
- Sentence read verbatim from the capture set: "Change colors here. Your values stay the same."
- The guide boxes stayed outside the highlighted guide target area in the inspected captures.
- Deviations from v6: none.

## T31 Milestone 9: Student Blockers And Deployment Prep

Source lists read and merged:
- ROOT list in this report: start path, SPSS row choice, p direction and .000, validation failure priority, copyable claims.
- ANIM_CODEX list in `D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\ONBOARDING\ONBOARDING_DESIGN_2026-08-31_v6_EN.md`: SPSS row labels, p = .000, alpha, decimal df, causal claims.
- User-observed blockers added this run: repeated SPSS radio subtitles and missing confidence-level guidance.

Merged blocker status:
- Start path: already fixed in T30, strengthened on the input page this run.
- SPSS row choice: fixed this run with Levene-aware radio subtitles; the app still never auto-selects between both SPSS rows.
- p direction and SPSS .000: fixed in T30, strengthened this run with p-direction radio subtitles.
- Alpha: fixed in T30, strengthened this run by showing the normal .05 default while keeping it tied to the course.
- Decimal Welch df: already fixed in T30 and unchanged.
- Validation failure priority: already fixed in T30, wording tightened this run.
- Copyable APA wording versus unsupported causal claims: already fixed in T30 and unchanged.
- Missing confidence level: fixed this run with location and value guidance.

Before/after wording changed this run:

| Area | Before | After |
| --- | --- | --- |
| Paste page body | "Paste, load an example, then review." | "Paste SPSS, JASP, jamovi, or APA output." |
| Example page body | "Review it, or choose another example." | "Review the detected values before reporting." |
| Manual page body | "Fill the numbers, then check them." | "Type values from one output row." |
| SPSS assumed subtitle, Levene parsed | "Equal variances assumed" | "Student row. Levene's Sig. = 0.525; with .05 rule, SPSS points to this row." |
| SPSS not-assumed subtitle, Levene parsed | "Equal variances not assumed" | "Welch row. Levene's Sig. = 0.525; with .05 rule, use this only if assigned." |
| SPSS assumed subtitle, Levene not parsed | "Equal variances assumed" | "Student row. Use when Levene's Sig. is .05 or larger." |
| SPSS not-assumed subtitle, Levene not parsed | "Equal variances not assumed" | "Welch row. Use when Levene's Sig. is below .05." |
| Two-tailed p option | No subtitle. | "Use SPSS Sig. (2-tailed)." |
| Lower-tail p option | No subtitle. | "Use only if the assignment predicts lower values." |
| Upper-tail p option | No subtitle. | "Use only if the assignment predicts higher values." |
| Missing confidence field label | "reported confidence level" | "CI confidence level" |
| Missing confidence title | "reported confidence level missing" | "Enter the CI level, usually .95." |
| Missing confidence body | "Fix this before continuing." | "Look for 95% before Confidence Interval; type .95." |
| Missing t title | "reported t missing" | "Find t in the selected test row." |
| Missing t body | "Fix this before continuing." | "Copy the number from the t column." |
| Missing df title | "reported df missing" | "Find df in the selected test row." |
| Missing df body | "Fix this before continuing." | "Copy the df value; decimals are ok for Welch." |
| Missing p title | "reported p missing" | "Find p or Sig. in the selected test row." |
| Missing p body | "Fix this before continuing." | "Use Sig. (2-tailed), or type < .001 for SPSS .000." |
| Missing Group Statistics title | "`<field> missing`" | "Find this value in Group Statistics." |
| Missing Group 1 n body | "Fix this before continuing." | "Copy Group 1 N." |
| Missing Group 1 mean body | "Fix this before continuing." | "Copy Group 1 Mean." |
| Missing Group 1 SD body | "Fix this before continuing." | "Copy Group 1 Std. Deviation." |
| Missing Group 2 n body | "Fix this before continuing." | "Copy Group 2 N." |
| Missing Group 2 mean body | "Fix this before continuing." | "Copy Group 2 Mean." |
| Missing Group 2 SD body | "Fix this before continuing." | "Copy Group 2 Std. Deviation." |
| Missing reference title | "reference mean missing" | "Enter the test value for one sample." |
| Missing reference body | "Fix this before continuing." | "Use the comparison value named in your output or assignment." |
| Missing paired title | "`<field> missing`" | "Find this value in Paired Differences." |
| Missing paired mean body | "Fix this before continuing." | "Copy the Mean from the Paired Differences row." |
| Missing paired SD body | "Fix this before continuing." | "Copy the Std. Deviation from Paired Differences." |
| Missing fallback title | "`<field> missing`" | "`<field> was not found.`" |
| Missing fallback body | "Fix this before continuing." | "Choose or type the missing value before continuing." |
| Manual alpha label | "Alpha (course level)" | "Alpha (course, usually .05)" |
| Manual p-tail label | "Tail" | "p direction" |
| Manual confidence label | "Confidence level" | "CI level (usually .95)" |
| Validation page body | "Fix fails before generating the report." | "Fix failed rows before generating the report." |
| Validation blocking notice | "Fix failed values before generating a report." | "Fix failed rows before generating a report." |
| Failure summary body | "Fix before report." | "Fix failed rows first." |

Deployment prep:
- `.github/workflows/deploy-web.yml` builds web with `--base-href /RES-QUILL/`.
- The workflow creates `build/web/.nojekyll` before uploading the Pages artifact.
- Added `RELEASE_CHECKLIST.md` with GitHub Pages and Google Play release steps.
- Required Shir-owned Pages setting: `Settings -> Pages -> Source = GitHub Actions`.
- Published URL after Shir pushes and the workflow succeeds: `https://shir-openu.github.io/RES-QUILL/`.
- No push was made.

Cold build verification after `flutter clean` and `flutter pub get`:
- Web release: passed. Artifact path: `build\web\index.html`; built base href is `<base href="/RES-QUILL/">`; `.nojekyll` exists at `build\web\.nojekyll`.
- Windows debug: passed. Artifact path: `build\windows\x64\runner\Debug\res_quill.exe`.
- Android debug: passed. Artifact path: `build\app\outputs\flutter-apk\app-debug.apk`.
- Android note for Shir: the debug APK does not need release signing. Google Play needs a release keystore, Play Console setup, and accepted SDK licences on the build machine if prompted.

Verification:
- `dart format lib test tool`: passed.
- `flutter analyze`: passed.
- `flutter test`: 101 passed, 0 failed.
- `flutter test --update-goldens tool\verify\capture_app_screens_test.dart`: passed.
- Captures regenerated: 40 total; 16 tracked image files changed because the visible input and validation wording changed.
- Inspected `captures\desktop_dark_03_input_spss_independent.png`, `captures\desktop_dark_guide_03_input_spss_independent.png`, and `captures\desktop_dark_04_validation_failing.png`.
- Sentence read from the input capture: "Student row. Levene's Sig. = 0.525; with .05 rule, SPSS points to this row."
- Sentence read from the validation capture: "Fix failed rows before generating the report."

## T32 Validation Screen Clarity Fix

Contradiction resolved:
- The left validation tiles now claim "these are the reported values being checked," not independent green approvals.
- If a reported value is connected to a failing validation check, its tile renders as Error and points to the matching problem row by human title.
- This keeps the summary and the problem list consistent: `p = 0.999` no longer shows OK while the p-vs-t-and-df check fails.

Check ID audit:
- Validation check IDs are still internal, but the validation UI now shows human titles.
- Check ID families removed from validation UI: 10 (`domain.*`, `df.plausibility`, `t.descriptives`, `p.t_df`, `ci.diff_se`, `ci.lower`, `ci.upper`, `grim.*`, `alpha.domain`, `calculation.input`).
- Blocked report refusal text also uses human titles instead of check IDs.

Raw double audit:
- User-facing raw double display paths found and fixed: 2.
- Tolerance text now formats the rounding tolerance compactly instead of printing binary-floating-point noise.
- Pasted-number detail text now formats `PasteNumber` values with their captured decimal count rather than raw `double.toString()`.
- Effect sizes, CI bounds, p-values, percentages, and visible charts were already routed through `ApaNumberFormat` or the app display formatter.

Recaptured validation wording:
- Error row title: "Reported t matches the descriptive statistics"
- Error row body: "The reported t does not match the means, SDs, ns, and stated test. Given: 1. Calculated: 4.340. Allowed difference: value was rounded to 2 decimals, so tolerance is +/- 0.005."
- Error row title: "Reported p matches t and df"
- Error row body: "The reported p does not match the reported t and df. Given: 0.999. Calculated: 0.322. Allowed difference: value was rounded to 3 decimals, so tolerance is +/- 0.0005."
- Tolerance sentence quoted from the capture: "Allowed difference: value was rounded to 2 decimals, so tolerance is +/- 0.005."

Merged blocker list status after T32:
- Start path: fixed.
- SPSS row choice: fixed; the app still asks the student to confirm the row instead of silently choosing it.
- p direction and SPSS .000: fixed.
- Alpha: fixed.
- Decimal Welch df: fixed.
- Validation failure priority and clarity: fixed by T30/T31 and tightened by T32.
- Copyable APA wording versus unsupported causal claims: fixed.
- Missing confidence level: fixed.
- Remaining unfixed blockers from the merged list: 0.
- Physical Android device runtime check: UNKNOWN; not part of the merged blocker list and not rerun in T32.

Verification:
- `C:\flutter\bin\dart.bat format lib test tool`: passed.
- `C:\flutter\bin\flutter.bat analyze`: passed.
- `C:\flutter\bin\flutter.bat test`: 104 passed, 0 failed.
- `C:\flutter\bin\flutter.bat test --update-goldens tool\verify\capture_app_screens_test.dart`: passed.
- Recaptured and inspected `captures\desktop_dark_04_validation_failing.png` and `captures\phone390_dark_04_validation_failing.png`.
- Web, Windows, and Android builds: UNKNOWN in T32; not rerun.

## T39 New-Format Examples And Practice Folder

User problem addressed:
- A student could paste R, jamovi/JASP, and Excel ToolPak output only if she already had a file. The examples inside the app still showed only the older SPSS/APA cases.
- R console output is a special learner trap: R prints the test, CI, and means, but not N or SD.

Changes:
- Added bundled paste-text examples for `r_welch.txt`, `r_one_sample.txt`, `jamovi_welch.txt`, and `excel_toolpak_student.txt`.
- The new app example buttons are `R Welch`, `R one-sample`, `jamovi Welch`, and `Excel ToolPak`.
- The R examples use real `stats::t.test` console-output shape. No invented descriptives table is prepended.
- When R output is missing only N and SD, the paste review shows one line: "R prints means only; fill highlighted N and SD."
- The structured fields panel highlights the missing boxes without adding per-field help text.
- On desktop builds, the input panels show `Open sample text folder`. Pressing it writes the bundled paste-text examples to an app-data `sample_paste_text` folder and opens that folder.
- The folder control is hidden outside desktop IO platforms; web and Android do not show a dead button.
- The folder contains paste-text examples only. Raw CSV and raw Excel rows remain outside the MVP.

Asset provenance:
- `assets/examples/paste_text/r_welch.txt` matches `SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_r_welch.txt`.
- `assets/examples/paste_text/r_one_sample.txt` matches `SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_r_one_sample.txt`.
- `assets/examples/paste_text/jamovi_welch.txt` matches `SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_jamovi_welch.txt`.
- `assets/examples/paste_text/excel_toolpak_student.txt` matches `SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS\claude_excel_toolpak_student.txt`.
- Byte identity is covered by the widget test "new bundled example assets match source bytes".

Verification:
- `dart format --set-exit-if-changed lib test tool`: passed, 38 files checked and 0 changed.
- `dart run tool\verify\claude_check_paste.dart`: passed on the seven default `PASTE_TEXT` files.
- `dart run tool\verify\claude_check_paste.dart D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\CLAUDE_NEW_FORMATS`: passed on the 12 blind new-format files.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 152 passed and 0 failed.
- `flutter test tool\verify\t39_r_asset_app_test.dart`: passed. The bundled R Welch example reached the report after entering N `24`, SD `10.361928`, N `27`, and SD `14.005195`.
- T39 app/scipy values: t `3.286242536229062`, df `47.51367597657565`, p `0.0019131042118096797`; CI `[4.3685783516350165, 18.14962164836499]`.

## T41 SPSS Row Labels

Source:
- `ONBOARDING_DESIGN_2026-09-01_v7_EN.md` names the Student/Welch SPSS independent-samples row decision as the worst sticking point for a psychology student.

Change:
- The manual selection cards, manual test-type dropdown, and SPSS both-rows ambiguity choices now use `SPSS row: Equal variances assumed` for Student and `SPSS row: Equal variances not assumed` for Welch.
- No guide step was added, and the start headline was left unchanged at that point.

## 2026-09-01 - start headline set to the brief

Shir ruled on the headline: use the one specified in `MESSAGE_TO_CLAUDE_ON_30_AUG_2026.txt`.

Change:
- Headline is now `Turn statistical output into a clear, report-ready result.`
- The line below it is now the brief's sub-line, `Paste or enter key values, understand the result, check inconsistencies, and generate clear academic wording.`, replacing `Start with your SPSS table or APA sentence.` which named only two of the five supported formats.
- The headline is longer, so it is sized by available width - 30 / 26 / 22 - and the surrounding spacing was tightened. Without this the panel grew tall enough to push the three action buttons, and the guide's first tip, out of a 390-wide viewport; eight tests caught that.

Verification:
- `flutter analyze`: no issues. `flutter test`: 159 passed, 0 failed, including the T45 guide geometry test at both widths.
- Captures read at 1440x1000 and 390x900 in both themes: `captures/headline_*_start.png`. Headline, sub-line and all three actions visible; nothing occluded.

Verification:
- `C:\flutter\bin\dart.bat format --set-exit-if-changed lib test tool`: passed, 0 files changed.
- `C:\flutter\bin\flutter.bat analyze`: passed, no issues found.
- `C:\flutter\bin\flutter.bat test`: passed, 154 passed and 0 failed.
- Fresh Chrome CDP captures from the rebuilt web app: `captures\t41_selection_desktop_1440x1000.png` at 1440x1000, `captures\t41_selection_mobile_390x900.png` at 390x900, `captures\t41_ambiguity_desktop_1440x1000.png` at 1440x1000, and `captures\t41_ambiguity_mobile_390x900.png` at 390x900.
