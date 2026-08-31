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
