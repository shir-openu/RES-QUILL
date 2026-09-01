# Paste Parser Report - 2026-08-30

T38 status: the T37 parser repair was correct for the synthesized corpus, but the R fixtures were self-confirming. They prepended a `Descriptives` table that R `stats::t.test()` does not emit. The parser now accepts genuine R console output without N or SD, extracts the values R actually prints, and returns `needsConfirmation` for the missing descriptives. Separate R fixtures now cover the optional user-prepended descriptives path.

## Formats Supported

1. SPSS one-sample, independent-samples, and paired-samples t-test output already covered by the T24/T35 fixture corpus.
2. APA-style t-test prose already covered by the T24/T35 fixture corpus.
3. R `stats::t.test()` console output for Welch two-sample, equal-variance two-sample, paired, and one-sample t-tests. Genuine R output is accepted without descriptives: the parser extracts method, t, df, p including strict inequalities such as `p-value < 2.2e-16`, alternative-hypothesis tail, confidence interval bounds, sample estimates, and one-sample `mu`. Because R does not print N or SD, those fields are requested from the student via the existing `needsConfirmation` path. If a user prepends a separate `Descriptives` table, the parser uses it and can return `confident`.
4. JASP and jamovi compact t-test tables when they include `Statistic`, `df`, `p`, a supported Student/Welch/paired/one-sample row, and a separate descriptives block. Shape references: https://jasp-stats.org/2018/04/18/how-to-conduct-a-classical-independent-sample-t-test-in-jasp-and-interpret-the-results/, https://jasp-stats.org/2018/01/09/classical-one-sample-t-test-jasp-interpret-results/, and https://jamovi.readthedocs.io/is/latest/spss2jamovi/s2j_ttestIS/.
5. Excel Analysis ToolPak t-test output for `t-Test: Two-Sample Assuming Equal Variances`, `t-Test: Two-Sample Assuming Unequal Variances`, and `t-Test: Paired Two Sample for Means`. The `Alpha` row is used when present. If a partial paste omits it, the parser now returns `needsConfirmation` and asks for the CI confidence level instead of refusing the whole paste. Shape reference: https://support.microsoft.com/en-us/office/use-the-analysis-toolpak-to-perform-complex-data-analysis-6c67ccf0-f4a9-487c-8dec-bdb5a2cefab6.

## Formats Refused

1. Raw CSV/Excel data rows, because Res-Quill does not compute a test from unanalysed observations.
2. ANOVA, chi-square, correlation, regression, z-test, and non-parametric output, even when they contain values named `t`, `df`, or `p`.
3. R `t.test()` blocks missing core test statistics, the confidence interval, sample estimates, the alternative-hypothesis direction, or the one-sample reference mean.
4. JASP/jamovi tables missing the `p` column, descriptives, or a supported one-row t-test result.
5. Multiple supported JASP/jamovi t-test result rows in one pasted table, unless a future UI asks the user to choose.

## Fixture Provenance

| Fixture | Format | Provenance | Independent check |
| --- | --- | --- | --- |
| `R_IND01_WELCH_FLOOR` | R Welch two-sample | Genuine R console shape without descriptives | parser must request N and SD |
| `R_IND01_WELCH_FLOOR_WITH_DESC` | R Welch two-sample | Genuine R console shape plus prepended descriptives | scipy Welch from fixture descriptives |
| `R_IND02_STUDENT_VAR_EQUAL` | R equal-variance two-sample | Genuine R console shape without descriptives | parser must request N and SD |
| `R_IND02_STUDENT_VAR_EQUAL_WITH_DESC` | R equal-variance two-sample | Genuine R console shape plus prepended descriptives | scipy Student from fixture descriptives |
| `R_ONE01_BASE_CONSOLE` | R one-sample | Genuine R console shape without descriptives | parser must request N and SD |
| `R_ONE01_BASE_CONSOLE_WITH_DESC` | R one-sample | Genuine R console shape plus prepended descriptives | scipy one-sample from fixture descriptives |
| `R_PAIR01_BASE_CONSOLE` | R paired | Genuine R console shape without descriptives | parser must request marginal descriptives and difference SD |
| `R_PAIR01_BASE_CONSOLE_WITH_DESC` | R paired | Genuine R console shape plus prepended marginal and paired-difference descriptives | scipy paired from fixture descriptives |
| `JASP_IND01_WELCH_TABLE` | JASP independent Welch | Synthesized from sourced JASP table shape | scipy Welch from fixture descriptives |
| `JAMOVI_IND01_STUDENT_TABLE` | jamovi independent Student | Synthesized from sourced jamovi table shape | scipy Student from fixture descriptives |
| `JASP_ONE01_TABLE` | JASP one-sample | Synthesized from sourced JASP table shape | scipy one-sample from fixture descriptives |
| `JAMOVI_PAIR01_TABLE` | jamovi paired | Synthesized from sourced paired table shape | scipy paired from fixture descriptives |
| `EXCEL_IND01_EQUAL_VARIANCES` | Excel ToolPak equal variances | Synthesized from sourced ToolPak row labels | scipy Student from fixture descriptives |
| `EXCEL_IND03_EQUAL_VARIANCES_NO_ALPHA` | Excel ToolPak equal variances | Synthesized ToolPak partial paste without `Alpha` | parser must request CI confidence level |
| `EXCEL_IND02_UNEQUAL_VARIANCES` | Excel ToolPak unequal variances | Synthesized from sourced ToolPak row labels | scipy Welch from fixture descriptives |
| `EXCEL_PAIR01_PAIRED` | Excel ToolPak paired | Synthesized from sourced ToolPak row labels | scipy paired-correlation formula from fixture descriptives |
| `R_NEG01_TRUNCATED` | Negative R | Truncated sourced R shape | Refuses missing sample estimates |
| `JAMOVI_NEG01_MISSING_P` | Negative jamovi/JASP | Sourced table shape with `p` removed | Refuses missing p column |
| `R_NEG02_CORRELATION` | Negative R correlation | Sourced unsupported output family | Refuses correlation |
| `R_NEG03_WILCOXON` | Negative R Wilcoxon | Sourced unsupported output family | Refuses Wilcoxon |
| `EXCEL_NEG01_ZTEST` | Negative Excel | Sourced unsupported ToolPak output family | Refuses z-test |

Positive fixture count: 4 genuine R console shapes without descriptives, 4 R console shapes with prepended descriptives, 8 other supported paste shapes, and 1 Excel partial-selection shape. Negative fixture count: 5. Fixtures that include enough descriptives keep `scipyCheck: true`; the Dart fixture test calls `tool/verify/scipy_paste_fixture_check.py` and compares parsed t, df, and p against scipy-derived values from the fixture descriptives.

## OPINION

The riskiest confident-looking wrong parse is still compact table output.
JASP, jamovi, copied HTML, PDFs, and spreadsheets can collapse columns differently.
The parser now requires a p column and separate descriptives, but whitespace can lie.
Paired tests are second-riskiest when only marginal SDs are visible.
Excel paired output is acceptable only because Pearson correlation is present.
R is lower risk because the console block has stronger method markers, but genuine R output cannot be fully validated until the student supplies N and SD.
The R `p-value < 2.2e-16` floor is intentionally stored as a strict inequality.
One-sample R confidence intervals are parsed as reported console bounds, while the generated report still computes its own confidence interval from the completed validation input.
