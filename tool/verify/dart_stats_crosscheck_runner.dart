import 'dart:convert';
import 'dart:io';

import 'package:res_quill/src/stats/stats.dart';

void main() async {
  final input = await stdin.transform(utf8.decoder).join();
  final cases = jsonDecode(input) as List<dynamic>;
  final results = <Map<String, dynamic>>[];

  for (final item in cases.cast<Map<String, dynamic>>()) {
    try {
      final result = _runCase(item);
      results.add({
        'id': item['id'],
        'kind': item['kind'],
        'mode': item['mode'],
        't': result.t,
        'df': result.degreesOfFreedom,
        'pTwoTailed': result.pTwoTailed,
        'pOneTailed': result.pOneTailed,
        'pLess': result.pLess,
        'pGreater': result.pGreater,
        'meanDifference': result.meanDifference,
        'standardError': result.standardError,
        'ciLower': result.confidenceInterval.lower,
        'ciUpper': result.confidenceInterval.upper,
        'cohensD': result.effectSize.cohensD,
        'hedgesG': result.effectSize.hedgesG,
      });
    } on Object catch (error) {
      results.add({
        'id': item['id'],
        'kind': item['kind'],
        'mode': item['mode'],
        'error': error.toString(),
      });
    }
  }

  stdout.write(jsonEncode(results));
}

TTestResult _runCase(Map<String, dynamic> item) {
  final confidenceLevel = (item['confidenceLevel'] as num?)?.toDouble() ?? 0.95;
  final kind = item['kind'] as String;
  final mode = item['mode'] as String;

  return switch ((kind, mode)) {
    ('student', 'summary') => TTests.independentStudentFromSummary(
      first: _summary(item['first'] as Map<String, dynamic>),
      second: _summary(item['second'] as Map<String, dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('student', 'raw') => TTests.independentStudentFromRaw(
      first: _values(item['firstValues'] as List<dynamic>),
      second: _values(item['secondValues'] as List<dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('welch', 'summary') => TTests.independentWelchFromSummary(
      first: _summary(item['first'] as Map<String, dynamic>),
      second: _summary(item['second'] as Map<String, dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('welch', 'raw') => TTests.independentWelchFromRaw(
      first: _values(item['firstValues'] as List<dynamic>),
      second: _values(item['secondValues'] as List<dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('paired', 'summary') => TTests.pairedFromSummary(
      summary: _pairedSummary(item['paired'] as Map<String, dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('paired', 'raw') => TTests.pairedFromRaw(
      first: _values(item['firstValues'] as List<dynamic>),
      second: _values(item['secondValues'] as List<dynamic>),
      confidenceLevel: confidenceLevel,
    ),
    ('one_sample', 'summary') => TTests.oneSampleFromSummary(
      sample: _summary(item['sample'] as Map<String, dynamic>),
      referenceMean: (item['referenceMean'] as num).toDouble(),
      confidenceLevel: confidenceLevel,
    ),
    ('one_sample', 'raw') => TTests.oneSampleFromRaw(
      values: _values(item['values'] as List<dynamic>),
      referenceMean: (item['referenceMean'] as num).toDouble(),
      confidenceLevel: confidenceLevel,
    ),
    _ => throw StatsException('Unsupported cross-check case: $kind/$mode'),
  };
}

SummaryStats _summary(Map<String, dynamic> value) {
  return SummaryStats(
    n: value['n'] as int,
    mean: (value['mean'] as num).toDouble(),
    standardDeviation: (value['sd'] as num).toDouble(),
  );
}

PairedSummaryStats _pairedSummary(Map<String, dynamic> value) {
  return PairedSummaryStats(
    n: value['n'] as int,
    firstMean: (value['firstMean'] as num).toDouble(),
    firstStandardDeviation: (value['firstSd'] as num).toDouble(),
    secondMean: (value['secondMean'] as num).toDouble(),
    secondStandardDeviation: (value['secondSd'] as num).toDouble(),
    meanDifference: (value['meanDifference'] as num).toDouble(),
    differenceStandardDeviation: (value['differenceSd'] as num).toDouble(),
  );
}

List<double> _values(List<dynamic> values) {
  return values.map((value) => (value as num).toDouble()).toList();
}
