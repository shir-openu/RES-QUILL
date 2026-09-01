import 'dart:convert';
import 'dart:io';

import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = _loadFixtures().where((fixture) => fixture.scipyCheck);

  group('new paste fixtures match scipy from parsed descriptives', () {
    for (final fixture in fixtures) {
      test(fixture.id, () {
        final result = TTestPasteParser.parse(fixture.input);
        expect(result.status, isNot(PasteParseStatus.cannotParse));

        final candidate = result.candidates.singleWhere(
          (candidate) => candidate.kind.name == fixture.expectedSelectedKind,
        );
        final tail =
            candidate.reportedPValueTail ?? ReportedPValueTail.twoTailed;
        final validationInput = candidate.toValidationInput(
          confirmedPValueTail: tail,
        );
        final scipy = _scipyFrom(validationInput);

        _expectAccepts(
          fixture.id,
          't',
          candidate.number(PasteFieldKey.reportedT)!,
          scipy.t,
        );
        _expectAccepts(
          fixture.id,
          'df',
          candidate.number(PasteFieldKey.reportedDegreesOfFreedom)!,
          scipy.df,
        );
        _expectAccepts(
          fixture.id,
          'p',
          candidate.number(PasteFieldKey.reportedP)!,
          scipy.p,
        );
      });
    }
  });
}

void _expectAccepts(
  String fixtureId,
  String label,
  PasteNumber reported,
  double scipyValue,
) {
  final value = reported.toReportedValue();
  expect(
    value.accepts(scipyValue, minimumTolerance: label == 't' ? 0.005 : 0),
    isTrue,
    reason:
        '$fixtureId $label parsed ${reported.relationSymbol} '
        '${reported.value} did not accept scipy $scipyValue',
  );
}

_ScipyResult _scipyFrom(TTestValidationInput input) {
  final result = Process.runSync('python', [
    'tool/verify/scipy_paste_fixture_check.py',
    jsonEncode(_payload(input)),
  ]);
  if (result.exitCode != 0) {
    fail(
      'scipy fixture helper failed with exit ${result.exitCode}\n'
      'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }
  return _ScipyResult.fromJson(
    jsonDecode(result.stdout as String) as Map<String, Object?>,
  );
}

Map<String, Object?> _payload(TTestValidationInput input) {
  return {
    'kind': input.kind.name,
    'tail': input.reportedPValueTail.name,
    'confidenceLevel': input.confidenceLevel,
    if (input.first != null) 'first': _descriptives(input.first!),
    if (input.second != null) 'second': _descriptives(input.second!),
    if (input.referenceMean != null) 'referenceMean': input.referenceMean,
    if (input.paired != null) 'paired': _paired(input.paired!),
  };
}

Map<String, Object?> _descriptives(ReportedDescriptives item) {
  return {
    'n': item.n,
    'mean': item.mean,
    'standardDeviation': item.standardDeviation,
  };
}

Map<String, Object?> _paired(ReportedPairedDescriptives item) {
  return {
    'first': _descriptives(item.first),
    'second': _descriptives(item.second),
    if (item.meanDifference != null) 'meanDifference': item.meanDifference,
    if (item.differenceStandardDeviation != null)
      'differenceStandardDeviation': item.differenceStandardDeviation,
    if (item.correlation != null) 'correlation': item.correlation,
  };
}

List<_Fixture> _loadFixtures() {
  final file = File('test/paste/fixtures/paste_fixtures.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final fixtures = decoded['fixtures']! as List<Object?>;
  return fixtures
      .map((fixture) => _Fixture.fromJson(fixture! as Map<String, Object?>))
      .toList();
}

class _Fixture {
  const _Fixture({
    required this.id,
    required this.input,
    required this.scipyCheck,
    required this.expectedSelectedKind,
  });

  factory _Fixture.fromJson(Map<String, Object?> json) {
    final expected = json['expected']! as Map<String, Object?>;
    return _Fixture(
      id: json['id']! as String,
      input: json['input']! as String,
      scipyCheck: json['scipyCheck'] == true,
      expectedSelectedKind: expected['selectedKind'] as String?,
    );
  }

  final String id;
  final String input;
  final bool scipyCheck;
  final String? expectedSelectedKind;
}

class _ScipyResult {
  const _ScipyResult({required this.t, required this.df, required this.p});

  factory _ScipyResult.fromJson(Map<String, Object?> json) {
    return _ScipyResult(
      t: (json['t']! as num).toDouble(),
      df: (json['df']! as num).toDouble(),
      p: (json['p']! as num).toDouble(),
    );
  }

  final double t;
  final double df;
  final double p;
}
