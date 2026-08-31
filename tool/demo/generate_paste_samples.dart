import 'dart:convert';
import 'dart:io';

import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';

const outputPath =
    r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\PASTE_SAMPLES_2026-08-30_EN.html';
const fixturePath = 'test/paste/fixtures/paste_fixtures.json';

void main() {
  final fixtures = _loadFixtures();
  final rendered = fixtures.map(_renderFixture).toList();
  File(outputPath).writeAsStringSync(_page(rendered));
  stdout.writeln('Wrote $outputPath');
  stdout.writeln('Fixtures: ${fixtures.length}');
  stdout.writeln(
    'Confident parses: '
    '${rendered.where((item) => item.result.status == PasteParseStatus.confident).length}',
  );
}

_RenderedFixture _renderFixture(_Fixture fixture) {
  final result = TTestPasteParser.parse(fixture.input);
  TTestReportOutput? report;
  List<ValidationCheck> checks = const [];
  String? reportError;
  if (result.status == PasteParseStatus.confident &&
      result.selectedCandidate != null) {
    try {
      final candidate = result.selectedCandidate!;
      final validationInput = candidate.toValidationInput();
      final computed = TTestValidator.resultFromInput(validationInput);
      checks = TTestValidator.validate(validationInput);
      report = TTestReportGenerator.generate(
        result: computed,
        validationChecks: checks,
        context: candidate.reportContext(),
        options: candidate.reportOptions(),
        evidenceSources: candidate.evidenceSources(),
      );
    } on Object catch (error) {
      reportError = error.toString();
    }
  }
  return _RenderedFixture(
    fixture: fixture,
    result: result,
    report: report,
    checks: checks,
    reportError: reportError,
  );
}

List<_Fixture> _loadFixtures() {
  final decoded =
      jsonDecode(File(fixturePath).readAsStringSync()) as Map<String, Object?>;
  return (decoded['fixtures']! as List<Object?>)
      .map((item) => _Fixture.fromJson(item! as Map<String, Object?>))
      .toList();
}

String _page(List<_RenderedFixture> fixtures) {
  final buffer = StringBuffer()
    ..write('''
<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Res-Quill Paste Parser Samples</title>
<style>
:root {
  color-scheme: dark;
  --bg: #0F172A;
  --surface: #1E293B;
  --surface-2: #111827;
  --text: #E5E7EB;
  --muted: #CBD5E1;
  --line: #334155;
  --title: #FFFFFF;
  --accent: #38BDF8;
  --warning: #FDE68A;
  --blocked: #FCA5A5;
  --pass: #A7F3D0;
  --mark-bg: #854D0E;
  --mark-text: #FFFFFF;
}
:root[data-theme="light"] {
  color-scheme: light;
  --bg: #F8FAFC;
  --surface: #FFFFFF;
  --surface-2: #E2E8F0;
  --text: #0F172A;
  --muted: #334155;
  --line: #CBD5E1;
  --title: #FFFFFF;
  --accent: #0369A1;
  --warning: #854D0E;
  --blocked: #991B1B;
  --pass: #047857;
  --mark-bg: #FEF3C7;
  --mark-text: #0F172A;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 14px/1.5 Arial, Helvetica, sans-serif;
}
.topbar {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  padding: 16px 24px;
  background: #0F172A;
  border-bottom: 1px solid var(--line);
}
.topbar h1 {
  margin: 0;
  color: #FFFFFF;
  font-size: 18px;
  letter-spacing: 0;
}
button {
  min-width: 132px;
  border: 1px solid #94A3B8;
  background: #1E293B;
  color: #FFFFFF;
  padding: 9px 12px;
  border-radius: 6px;
  font-weight: 700;
  letter-spacing: 0;
  cursor: pointer;
}
main {
  width: min(1440px, 100%);
  margin: 0 auto;
  padding: 24px;
}
.case {
  margin: 0 0 18px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--surface);
  overflow: hidden;
}
.case-title {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
  padding: 14px 16px;
  background: #0F172A;
}
.case-title h2 {
  margin: 0;
  color: #FFFFFF;
  font-size: 16px;
  letter-spacing: 0;
}
.status {
  white-space: nowrap;
  font-weight: 800;
  color: var(--pass);
}
.status.needs { color: var(--warning); }
.status.cannot { color: var(--blocked); }
.content {
  display: grid;
  grid-template-columns: minmax(280px, 0.9fr) minmax(340px, 1.1fr);
  gap: 18px;
  padding: 16px;
}
section { min-width: 0; }
h3 {
  margin: 0 0 8px;
  font-size: 12px;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
pre, table, .wording {
  width: 100%;
  margin: 0 0 14px;
}
pre {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  padding: 12px;
  border: 1px solid var(--line);
  border-radius: 6px;
  background: var(--surface-2);
  color: var(--text);
}
mark {
  background: var(--mark-bg);
  color: var(--mark-text);
  border-radius: 3px;
  padding: 0 2px;
}
table {
  border-collapse: collapse;
  table-layout: fixed;
  font-size: 13px;
}
th, td {
  border: 1px solid var(--line);
  padding: 7px 8px;
  text-align: left;
  vertical-align: top;
  overflow-wrap: anywhere;
}
th {
  color: var(--muted);
  background: var(--surface-2);
}
.list {
  margin: 0 0 14px 20px;
  padding: 0;
}
.list li { margin: 0 0 4px; }
.source {
  color: var(--accent);
}
.muted {
  color: var(--muted);
}
.blocked {
  color: var(--blocked);
  font-weight: 700;
}
.wording p {
  margin: 0 0 10px;
}
@media (max-width: 900px) {
  .content { grid-template-columns: 1fr; }
  main { padding: 14px; }
  .topbar { padding: 12px 14px; }
}
</style>
</head>
<body>
<div class="topbar">
  <h1>RES-QUILL PASTE PARSER SAMPLES</h1>
  <button id="themeToggle" type="button">BRIGHT VIEW</button>
</div>
<main>
''');

  for (final fixture in fixtures) {
    buffer.write(_caseHtml(fixture));
  }

  buffer.write('''
</main>
<script>
const root = document.documentElement;
const button = document.getElementById('themeToggle');
function setTheme(theme) {
  root.setAttribute('data-theme', theme);
  button.textContent = theme === 'dark' ? 'BRIGHT VIEW' : 'DARK VIEW';
  try { localStorage.setItem('resQuillReportTheme', theme); } catch (_) {}
}
let saved = 'dark';
try { saved = localStorage.getItem('resQuillReportTheme') || 'dark'; } catch (_) {}
setTheme(saved);
button.addEventListener('click', () => {
  setTheme(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
});
</script>
</body>
</html>
''');
  return buffer.toString();
}

String _caseHtml(_RenderedFixture rendered) {
  final result = rendered.result;
  final status = result.status.name;
  final statusClass = switch (result.status) {
    PasteParseStatus.confident => 'status',
    PasteParseStatus.needsConfirmation => 'status needs',
    PasteParseStatus.cannotParse => 'status cannot',
  };
  return '''
<article class="case">
  <div class="case-title">
    <h2>${_h(rendered.fixture.id)} | ${_h(rendered.fixture.title)}</h2>
    <div class="$statusClass">${_h(status)}</div>
  </div>
  <div class="content">
    <section>
      <h3>Raw Paste</h3>
      <pre>${_highlight(rendered.fixture.input, result.fields)}</pre>
      <h3>Fixture Provenance</h3>
      <pre class="source">${_h(rendered.fixture.provenance.toUpperCase())}: ${_h(rendered.fixture.shapeSource)}</pre>
      <h3>Detected Fields</h3>
      ${_fieldTable(result.fields)}
    </section>
    <section>
      <h3>Parse Summary</h3>
      ${_candidateTable(result)}
      <h3>Ambiguities</h3>
      ${_ambiguitiesHtml(result)}
      <h3>Missing Required Fields</h3>
      ${_missingHtml(result)}
      <h3>Refusal Reasons</h3>
      ${_reasonsHtml(result)}
      <h3>Generated Wording</h3>
      ${_wordingHtml(rendered)}
    </section>
  </div>
</article>
''';
}

String _highlight(String input, List<PasteExtractedField<Object>> fields) {
  final ranges = fields.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart == 0 ? b.end.compareTo(a.end) : byStart;
    });
  final buffer = StringBuffer();
  var cursor = 0;
  for (final field in ranges) {
    if (field.start < cursor) {
      continue;
    }
    buffer.write(_h(input.substring(cursor, field.start)));
    buffer.write(
      '<mark title="${_h(field.key.label)}: ${_h(field.describeValue())}">'
      '${_h(input.substring(field.start, field.end))}</mark>',
    );
    cursor = field.end;
  }
  buffer.write(_h(input.substring(cursor)));
  return buffer.toString();
}

String _fieldTable(List<PasteExtractedField<Object>> fields) {
  if (fields.isEmpty) {
    return '<pre>No fields extracted.</pre>';
  }
  final buffer = StringBuffer(
    '<table><tr><th>Field</th><th>Value</th><th>Source</th>'
    '<th>Offsets</th><th>Confidence</th></tr>',
  );
  for (final field in fields) {
    final extra =
        field.value is PasteNumber &&
            (field.value as PasteNumber).spssRoundedZeroP
        ? ' SPSS .000 treated as p < .001.'
        : '';
    buffer.write(
      '<tr><td>${_h(field.keyPath)}</td><td>${_h(field.describeValue())}$extra</td>'
      '<td>${_h(field.sourceText)}</td><td>${field.start}-${field.end}</td>'
      '<td>${_h(field.confidence.toStringAsFixed(2))}</td></tr>',
    );
  }
  buffer.write('</table>');
  return buffer.toString();
}

String _candidateTable(TTestPasteParseResult result) {
  if (result.candidates.isEmpty) {
    return '<pre>No t-test candidate.</pre>';
  }
  final buffer = StringBuffer(
    '<table><tr><th>Candidate</th><th>Kind</th><th>Selected</th>'
    '<th>p tail</th><th>Missing</th></tr>',
  );
  for (final candidate in result.candidates) {
    final missing = candidate
        .missingRequiredFields()
        .map((field) => field.label)
        .join('; ');
    buffer.write(
      '<tr><td>${_h(candidate.label)}</td><td>${_h(candidate.kind.name)}</td>'
      '<td>${candidate.selectedByText ? 'yes' : 'no'}</td>'
      '<td>${_h(candidate.reportedPValueTail?.name ?? 'UNKNOWN')}</td>'
      '<td>${_h(missing.isEmpty ? 'none' : missing)}</td></tr>',
    );
  }
  buffer.write('</table>');
  return buffer.toString();
}

String _ambiguitiesHtml(TTestPasteParseResult result) {
  if (result.ambiguities.isEmpty) {
    return '<pre>None.</pre>';
  }
  final items = result.ambiguities
      .map((item) => '<li>${_h(item.id)}: ${_h(item.message)}</li>')
      .join();
  return '<ul class="list">$items</ul>';
}

String _missingHtml(TTestPasteParseResult result) {
  if (result.missingRequiredFields.isEmpty) {
    return '<pre>None.</pre>';
  }
  final items = result.missingRequiredFields
      .map((item) => '<li>${_h(item.label)}</li>')
      .join();
  return '<ul class="list">$items</ul>';
}

String _reasonsHtml(TTestPasteParseResult result) {
  if (result.refusalReasons.isEmpty) {
    return '<pre>None.</pre>';
  }
  final items = result.refusalReasons
      .map((reason) => '<li>${_h(reason)}</li>')
      .join();
  return '<ul class="list blocked">$items</ul>';
}

String _wordingHtml(_RenderedFixture rendered) {
  if (rendered.result.status != PasteParseStatus.confident) {
    return '<pre class="muted">Wording withheld until confirmation.</pre>';
  }
  if (rendered.reportError != null) {
    return '<pre class="blocked">${_h(rendered.reportError)}</pre>';
  }
  final report = rendered.report;
  if (report == null) {
    return '<pre class="muted">No generated wording.</pre>';
  }
  if (report.isBlocked) {
    return '<pre class="blocked">${_h(report.refusalReason)}</pre>';
  }
  final failures = rendered.checks
      .where((check) => check.status == ValidationStatus.fail)
      .map((check) => check.id)
      .join(', ');
  return '''
<div class="wording">
  <p><strong>Formal:</strong> ${_h(report.formalResult!.plainText)}</p>
  <p><strong>Descriptives:</strong> ${_h(report.descriptivesSentence!)}</p>
  <p><strong>Plain language:</strong> ${_h(report.plainLanguageMeaning!)}</p>
  <p><strong>Effect size:</strong> ${_h(report.effectSizeSentence!)}</p>
  <p><strong>Validation failures:</strong> ${_h(failures.isEmpty ? 'none' : failures)}</p>
</div>
''';
}

String _h(Object? value) {
  return (value ?? '').toString().replaceAllMapped(
    RegExp(
      r'[&<>"'
      ']',
    ),
    (match) => switch (match.group(0)) {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      "'" => '&#39;',
      _ => '',
    },
  );
}

class _Fixture {
  _Fixture({
    required this.id,
    required this.title,
    required this.provenance,
    required this.shapeSource,
    required this.input,
  });

  factory _Fixture.fromJson(Map<String, Object?> json) {
    return _Fixture(
      id: json['id']! as String,
      title: json['title']! as String,
      provenance: json['provenance']! as String,
      shapeSource: json['shapeSource']! as String,
      input: json['input']! as String,
    );
  }

  final String id;
  final String title;
  final String provenance;
  final String shapeSource;
  final String input;
}

class _RenderedFixture {
  _RenderedFixture({
    required this.fixture,
    required this.result,
    required this.report,
    required this.checks,
    required this.reportError,
  });

  final _Fixture fixture;
  final TTestPasteParseResult result;
  final TTestReportOutput? report;
  final List<ValidationCheck> checks;
  final String? reportError;
}
