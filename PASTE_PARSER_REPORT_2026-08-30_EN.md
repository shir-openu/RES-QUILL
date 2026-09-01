# Paste Parser Report - 2026-08-30

T37 status: the half-finished parser edit has been repaired, and the paste parser now supports the earlier SPSS, APA, and key-value paths plus the new R, JASP/jamovi, and Excel ToolPak t-test shapes below.

## Formats Supported

1. SPSS one-sample, independent-samples, and paired-samples t-test output already covered by the T24/T35 fixture corpus.
2. APA-style t-test prose already covered by the T24/T35 fixture corpus.
3. R `stats::t.test()` console output for Welch two-sample, equal-variance two-sample, paired, and one-sample t-tests. The implementation follows the official `t.test()` contract for `mu`, `paired`, `var.equal`, `conf.level`, statistic, df, p-value, confidence interval, estimate, and method: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/t.test.html. Console block shape and Welch default behavior are also checked against the Datanovia base-R examples: https://www.datanovia.com/learn/biostatistics/two-groups/t-test-in-r.
4. JASP and jamovi compact t-test tables when they include `Statistic`, `df`, `p`, a supported Student/Welch/paired/one-sample row, and a separate descriptives block. Shape references: https://jasp-stats.org/2018/04/18/how-to-conduct-a-classical-independent-sample-t-test-in-jasp-and-interpret-the-results/, https://jasp-stats.org/2018/01/09/classical-one-sample-t-test-jasp-interpret-results/, and https://jamovi.readthedocs.io/is/latest/spss2jamovi/s2j_ttestIS/.
5. Excel Analysis ToolPak t-test output for `t-Test: Two-Sample Assuming Equal Variances`, `t-Test: Two-Sample Assuming Unequal Variances`, and `t-Test: Paired Two Sample for Means`. Shape reference: https://support.microsoft.com/en-us/office/use-the-analysis-toolpak-to-perform-complex-data-analysis-6c67ccf0-f4a9-487c-8dec-bdb5a2cefab6.

## Formats Refused

1. Raw CSV/Excel data rows, because Res-Quill does not compute a test from unanalysed observations.
2. ANOVA, chi-square, correlation, regression, z-test, and non-parametric output, even when they contain values named `t`, `df`, or `p`.
3. R `t.test()` blocks missing the confidence interval, sample estimates, or validating descriptives.
4. JASP/jamovi tables missing the `p` column, descriptives, or a supported one-row t-test result.
5. Multiple supported JASP/jamovi t-test result rows in one pasted table, unless a future UI asks the user to choose.

## Fixture Provenance

| Fixture | Format | Provenance | Independent check |
| --- | --- | --- | --- |
| `R_IND01_WELCH_FLOOR` | R Welch two-sample | Synthesized from sourced R console shape | scipy Welch from fixture descriptives |
| `R_IND02_STUDENT_VAR_EQUAL` | R equal-variance two-sample | Synthesized from sourced R console shape | scipy Student from fixture descriptives |
| `R_ONE01_BASE_CONSOLE` | R one-sample | Sourced console block plus synthesized descriptives | scipy one-sample from fixture descriptives |
| `R_PAIR01_BASE_CONSOLE` | R paired | Sourced console block plus synthesized paired descriptives | scipy paired from fixture descriptives |
| `JASP_IND01_WELCH_TABLE` | JASP independent Welch | Synthesized from sourced JASP table shape | scipy Welch from fixture descriptives |
| `JAMOVI_IND01_STUDENT_TABLE` | jamovi independent Student | Synthesized from sourced jamovi table shape | scipy Student from fixture descriptives |
| `JASP_ONE01_TABLE` | JASP one-sample | Synthesized from sourced JASP table shape | scipy one-sample from fixture descriptives |
| `JAMOVI_PAIR01_TABLE` | jamovi paired | Synthesized from sourced paired table shape | scipy paired from fixture descriptives |
| `EXCEL_IND01_EQUAL_VARIANCES` | Excel ToolPak equal variances | Synthesized from sourced ToolPak row labels | scipy Student from fixture descriptives |
| `EXCEL_IND02_UNEQUAL_VARIANCES` | Excel ToolPak unequal variances | Synthesized from sourced ToolPak row labels | scipy Welch from fixture descriptives |
| `EXCEL_PAIR01_PAIRED` | Excel ToolPak paired | Synthesized from sourced ToolPak row labels | scipy paired-correlation formula from fixture descriptives |
| `R_NEG01_TRUNCATED` | Negative R | Truncated sourced R shape | Refuses missing estimates/descriptives |
| `JAMOVI_NEG01_MISSING_P` | Negative jamovi/JASP | Sourced table shape with `p` removed | Refuses missing p column |
| `R_NEG02_CORRELATION` | Negative R correlation | Sourced unsupported output family | Refuses correlation |
| `EXCEL_NEG01_ZTEST` | Negative Excel | Sourced unsupported ToolPak output family | Refuses z-test |

Positive fixture count: 2 sourced-console / 9 synthesized-from-sourced-shape. Negative fixture count: 4. Every positive T37 fixture has `scipyCheck: true`; the Dart fixture test calls `tool/verify/scipy_paste_fixture_check.py` and compares parsed t, df, and p against scipy-derived values from the fixture's own descriptives.

## OPINION

The riskiest confident-looking wrong parse is still compact table output.
JASP, jamovi, copied HTML, PDFs, and spreadsheets can collapse columns differently.
The parser now requires a p column and separate descriptives, but whitespace can lie.
Paired tests are second-riskiest when only marginal SDs are visible.
Excel paired output is acceptable only because Pearson correlation is present.
R is lower risk because the console block has stronger method markers.
The R `p-value < 2.2e-16` floor is intentionally stored as a strict inequality.
One-sample R confidence intervals are not imported as mean-difference CI fields.
That avoids treating a confidence interval around the mean as a difference interval.
