import 'dart:convert';
import 'dart:io';

import 'package:res_quill/src/paste/paste.dart';
import 'package:res_quill/src/report/report.dart';
import 'package:res_quill/src/stats/stats.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = _loadFixtures();

  group('paste fixture corpus', () {
    for (final fixture in fixtures) {
      test('${fixture.id} parses as expected', () {
        final result = TTestPasteParser.parse(fixture.input);

        expect(result.status.name, fixture.expectedStatus);
        expect(result.detectedTestKind?.name, fixture.expectedKind);
        expect(
          result.candidates.map((candidate) => candidate.kind.name).toList(),
          fixture.expectedCandidateKinds,
        );
        expect(
          result.ambiguities.map((ambiguity) => ambiguity.id).toList(),
          fixture.expectedAmbiguityIds,
        );

        if (result.status == PasteParseStatus.cannotParse) {
          expect(result.refusalReasons, isNotEmpty);
        }
        if (fixture.expectedRefusalReasons.isNotEmpty) {
          expect(result.refusalReasons, fixture.expectedRefusalReasons);
        }

        final detectedKeys = result.fields.map((field) => field.key).toSet();
        final missingKeys = result.missingRequiredFields
            .map((field) => field.key)
            .whereType<PasteFieldKey>()
            .toSet();
        expect(
          result.missingRequiredFields
              .map((field) => field.key?.path ?? field.reason)
              .toList(),
          fixture.expectedMissingKeys,
        );
        expect(
          detectedKeys.intersection(missingKeys),
          isEmpty,
          reason: '${fixture.id} reports a key as both detected and missing',
        );

        for (final field in result.fields) {
          expect(field.start, greaterThanOrEqualTo(0));
          expect(field.end, lessThanOrEqualTo(fixture.input.length));
          expect(field.end, greaterThan(field.start));
          expect(
            fixture.input.substring(field.start, field.end),
            field.sourceText,
          );
          expect(field.confidence, inInclusiveRange(0, 1));
        }

        final fieldSource = _fieldSourceFor(fixture, result);
        fixture.expectedFieldValues.forEach((keyPath, expectedValue) {
          final field = _fieldByPath(fieldSource, keyPath);
          expect(field, isNotNull, reason: '${fixture.id} missing $keyPath');
          final number = field!.value as PasteNumber;
          expect(
            number.value,
            closeTo(expectedValue, _tolerance(expectedValue)),
            reason: '${fixture.id} $keyPath',
          );
        });

        fixture.expectedFieldRelations.forEach((keyPath, relation) {
          final field = _fieldByPath(fieldSource, keyPath);
          expect(field, isNotNull, reason: '${fixture.id} missing $keyPath');
          final number = field!.value as PasteNumber;
          expect(number.relation.name, relation);
        });

        for (final keyPath in fixture.expectedRoundedZeroFields) {
          final field = _fieldByPath(fieldSource, keyPath);
          expect(field, isNotNull, reason: '${fixture.id} missing $keyPath');
          final number = field!.value as PasteNumber;
          expect(number.spssRoundedZeroP, isTrue);
          expect(number.relation, ReportedRelation.lessThan);
          expect(number.value, 0.001);
        }
      });
    }
  });

  group('paste round trip', () {
    for (final fixture in fixtures) {
      for (final chain in fixture.roundTrips) {
        test('${fixture.id} ${chain.candidateKind} reaches wording', () {
          final result = TTestPasteParser.parse(fixture.input);
          final candidate = result.candidates.singleWhere(
            (candidate) => candidate.kind.name == chain.candidateKind,
          );
          final tail = _tail(chain.confirmedTail);
          final validationInput = candidate.toValidationInput(
            confirmedPValueTail: tail,
          );
          final computed = TTestValidator.resultFromInput(validationInput);
          final checks = TTestValidator.validate(validationInput);
          final failures = checks
              .where((check) => check.status == ValidationStatus.fail)
              .toList();
          expect(
            failures,
            isEmpty,
            reason: failures.map((check) => check.explanation).join('\n'),
          );

          final report = TTestReportGenerator.generate(
            result: computed,
            validationChecks: checks,
            context: candidate.reportContext(),
            options: candidate.reportOptions(confirmedPValueTail: tail),
            evidenceSources: candidate.evidenceSources(),
          );

          expect(report.isBlocked, isFalse);
          expect(
            report.formalResult!.plainText,
            contains(chain.formalContains),
          );
        });
      }
    }

    test('unknown p tail blocks automatic validation-input conversion', () {
      final fixture = fixtures.singleWhere(
        (item) => item.id == 'APA04_UNKNOWN_TAIL',
      );
      final result = TTestPasteParser.parse(fixture.input);
      expect(result.status, PasteParseStatus.needsConfirmation);
      expect(
        () => result.candidates.single.toValidationInput(),
        throwsA(isA<PasteParseException>()),
      );
    });

    test('unknown p tail is an ambiguity, not a missing reported-p field', () {
      final fixture = fixtures.singleWhere(
        (item) => item.id == 'APA04_UNKNOWN_TAIL',
      );
      final result = TTestPasteParser.parse(fixture.input);

      expect(
        result.fields.map((field) => field.key),
        contains(PasteFieldKey.reportedP),
      );
      expect(
        result.missingRequiredFields.map((field) => field.key),
        isNot(contains(PasteFieldKey.reportedP)),
      );
      expect(result.missingRequiredFields, isEmpty);
    });
  });
}

List<PasteExtractedField<Object>> _fieldSourceFor(
  _Fixture fixture,
  TTestPasteParseResult result,
) {
  if (fixture.expectedSelectedKind != null) {
    return result.candidates
        .singleWhere(
          (candidate) => candidate.kind.name == fixture.expectedSelectedKind,
        )
        .fields;
  }
  return result.fields;
}

PasteExtractedField<Object>? _fieldByPath(
  List<PasteExtractedField<Object>> fields,
  String keyPath,
) {
  for (final field in fields) {
    if (field.keyPath == keyPath) {
      return field;
    }
  }
  return null;
}

double _tolerance(double expected) {
  return expected.abs() < 1 ? 1e-9 : expected.abs() * 1e-9;
}

ReportedPValueTail _tail(String value) {
  return switch (value) {
    'twoTailed' => ReportedPValueTail.twoTailed,
    'less' => ReportedPValueTail.less,
    'greater' => ReportedPValueTail.greater,
    'oneTailedObservedDirection' =>
      ReportedPValueTail.oneTailedObservedDirection,
    _ => throw ArgumentError('Unknown p tail $value'),
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
  _Fixture({
    required this.id,
    required this.input,
    required this.expectedStatus,
    required this.expectedKind,
    required this.expectedCandidateKinds,
    required this.expectedSelectedKind,
    required this.expectedAmbiguityIds,
    required this.expectedFieldValues,
    required this.expectedFieldRelations,
    required this.expectedRoundedZeroFields,
    required this.expectedRefusalReasons,
    required this.expectedMissingKeys,
    required this.roundTrips,
  });

  factory _Fixture.fromJson(Map<String, Object?> json) {
    final expected = json['expected']! as Map<String, Object?>;
    return _Fixture(
      id: json['id']! as String,
      input: json['input']! as String,
      expectedStatus: expected['status']! as String,
      expectedKind: expected['detectedKind'] as String?,
      expectedCandidateKinds: (expected['candidateKinds']! as List<Object?>)
          .cast<String>(),
      expectedSelectedKind: expected['selectedKind'] as String?,
      expectedAmbiguityIds: (expected['ambiguityIds']! as List<Object?>)
          .cast<String>(),
      expectedFieldValues: (expected['fieldValues']! as Map<String, Object?>)
          .map((key, value) => MapEntry(key, (value! as num).toDouble())),
      expectedFieldRelations:
          ((expected['fieldRelations'] as Map<String, Object?>?) ?? {})
              .cast<String, String>(),
      expectedRoundedZeroFields:
          ((expected['spssRoundedZeroFields'] as List<Object?>?) ?? const [])
              .cast<String>(),
      expectedRefusalReasons:
          ((expected['refusalReasons'] as List<Object?>?) ?? const [])
              .cast<String>(),
      expectedMissingKeys:
          ((expected['missingKeys'] as List<Object?>?) ?? const [])
              .cast<String>(),
      roundTrips: (json['roundTrip']! as List<Object?>)
          .map((item) => _RoundTrip.fromJson(item! as Map<String, Object?>))
          .toList(),
    );
  }

  final String id;
  final String input;
  final String expectedStatus;
  final String? expectedKind;
  final List<String> expectedCandidateKinds;
  final String? expectedSelectedKind;
  final List<String> expectedAmbiguityIds;
  final Map<String, double> expectedFieldValues;
  final Map<String, String> expectedFieldRelations;
  final List<String> expectedRoundedZeroFields;
  final List<String> expectedRefusalReasons;
  final List<String> expectedMissingKeys;
  final List<_RoundTrip> roundTrips;
}

class _RoundTrip {
  _RoundTrip({
    required this.candidateKind,
    required this.confirmedTail,
    required this.formalContains,
  });

  factory _RoundTrip.fromJson(Map<String, Object?> json) {
    return _RoundTrip(
      candidateKind: json['candidateKind']! as String,
      confirmedTail: json['confirmedTail']! as String,
      formalContains: json['formalContains']! as String,
    );
  }

  final String candidateKind;
  final String confirmedTail;
  final String formalContains;
}
