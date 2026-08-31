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
