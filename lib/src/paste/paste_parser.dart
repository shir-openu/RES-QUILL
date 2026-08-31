import 'dart:math' as math;

import '../stats/stats.dart';
import 'paste_result.dart';

class TTestPasteParser {
  TTestPasteParser._();

  static TTestPasteParseResult parse(String input) {
    final early = _earlyRefusal(input);
    if (early != null) {
      return early;
    }

    final lines = _splitLines(input);
    final parsers = [
      _parseSpssIndependent,
      _parseSpssPaired,
      _parseSpssOneSample,
      _parseApa,
      _parseKeyValue,
    ];

    for (final parser in parsers) {
      final parsed = parser(input, lines);
      if (parsed != null) {
        return parsed;
      }
    }

    return _cannotParse(input, [
      if (_looksLikeRawData(input))
        'Raw data table detected; paste parsing expects statistical output.',
      'No supported t-test output shape was found.',
    ]);
  }

  static TTestPasteParseResult? _parseSpssIndependent(
    String input,
    List<_Line> lines,
  ) {
    final rows = <_IndependentRow>[];
    for (final line in lines) {
      final lower = line.folded;
      if (lower.contains('equal variances not assumed')) {
        final row = _parseIndependentResultRow(
          line,
          kind: TTestKind.independentWelch,
          phrase: 'equal variances not assumed',
          input: input,
        );
        if (row != null) {
          rows.add(row);
        }
      } else if (lower.contains('equal variances assumed')) {
        final row = _parseIndependentResultRow(
          line,
          kind: TTestKind.independentStudent,
          phrase: 'equal variances assumed',
          input: input,
        );
        if (row != null) {
          rows.add(row);
        }
      }
    }

    if (rows.isEmpty) {
      return null;
    }

    final groupFields = _extractSpssGroupRows(
      lines,
      startMarkers: const ['group statistics'],
      endMarkers: const ['independent samples test'],
      order: _GroupRowOrder.nMeanSd,
      confidence: 0.95,
    );
    final commonFields = [...groupFields, ?_confidenceLevelField(input)];
    final selectedKind = _selectedIndependentKind(input);
    final candidates = rows.map((row) {
      return PasteTTestCandidate(
        kind: row.kind,
        label: row.kind == TTestKind.independentStudent
            ? 'Equal variances assumed'
            : 'Equal variances not assumed',
        fields: [...commonFields, ...row.fields],
        reportedPValueTail: row.tail,
        selectedByText: selectedKind == row.kind || rows.length == 1,
        format: 'SPSS independent-samples t-test',
        confidence: selectedKind == row.kind || rows.length == 1 ? 0.96 : 0.86,
      );
    }).toList();

    final ambiguities = <PasteAmbiguity>[];
    if (rows.length > 1 && selectedKind == null) {
      ambiguities.add(
        PasteAmbiguity(
          id: 'independent.variance_row',
          message:
              'SPSS reported both equal-variance rows; Student versus Welch '
              'must be chosen by the user.',
          fieldKeys: const [
            PasteFieldKey.reportedT,
            PasteFieldKey.reportedDegreesOfFreedom,
            PasteFieldKey.reportedP,
          ],
          candidateLabels: candidates
              .map((candidate) => candidate.label)
              .toList(),
        ),
      );
    }

    return _finish(
      input: input,
      candidates: candidates,
      ambiguities: ambiguities,
    );
  }

  static _IndependentRow? _parseIndependentResultRow(
    _Line line, {
    required TTestKind kind,
    required String phrase,
    required String input,
  }) {
    final match = RegExp(phrase, caseSensitive: false).firstMatch(line.text);
    if (match == null) {
      return null;
    }
    final tokens = _numbersInLine(line, startInLine: match.end);
    if (tokens.length < 7) {
      return null;
    }

    final resultStart =
        kind == TTestKind.independentStudent && tokens.length >= 9 ? 2 : 0;
    if (tokens.length - resultStart < 7) {
      return null;
    }

    final fields = <PasteExtractedField<Object>>[];
    if (kind == TTestKind.independentStudent && tokens.length >= 9) {
      fields
        ..add(_numberField(PasteFieldKey.leveneF, tokens[0], confidence: 0.90))
        ..add(
          _numberField(
            PasteFieldKey.leveneP,
            tokens[1],
            confidence: 0.90,
            pValue: true,
          ),
        );
    }

    final resultTokens = tokens.sublist(resultStart);
    fields
      ..add(_numberField(PasteFieldKey.reportedT, resultTokens[0]))
      ..add(
        _numberField(PasteFieldKey.reportedDegreesOfFreedom, resultTokens[1]),
      )
      ..add(
        _numberField(PasteFieldKey.reportedP, resultTokens[2], pValue: true),
      )
      ..add(_numberField(PasteFieldKey.reportedMeanDifference, resultTokens[3]))
      ..add(_numberField(PasteFieldKey.reportedStandardError, resultTokens[4]))
      ..add(_numberField(PasteFieldKey.ciLower, resultTokens[5]))
      ..add(_numberField(PasteFieldKey.ciUpper, resultTokens[6]));

    return _IndependentRow(
      kind: kind,
      fields: fields,
      tail: _tailFromContext(input, line.text),
    );
  }

  static TTestPasteParseResult? _parseSpssPaired(
    String input,
    List<_Line> lines,
  ) {
    if (!_containsFolded(input, 'paired samples test') &&
        !_containsFolded(input, 'paired samples statistics')) {
      return null;
    }

    final statFields = _extractSpssGroupRows(
      lines,
      startMarkers: const ['paired samples statistics'],
      endMarkers: const ['paired samples correlations', 'paired samples test'],
      order: _GroupRowOrder.meanNSd,
      confidence: 0.93,
      dropPairOrdinal: true,
    );

    final resultFields = <PasteExtractedField<Object>>[];
    final testStart = _lineIndexContaining(lines, 'paired samples test');
    if (testStart != -1) {
      for (var i = testStart + 1; i < lines.length; i += 1) {
        final line = lines[i];
        if (_isHeaderLike(line)) {
          continue;
        }
        final tokens = _dataNumbersInLine(line, dropPairOrdinal: true);
        if (tokens.length < 8) {
          continue;
        }
        resultFields
          ..add(_numberField(PasteFieldKey.pairedMeanDifference, tokens[0]))
          ..add(
            _numberField(
              PasteFieldKey.pairedDifferenceStandardDeviation,
              tokens[1],
            ),
          )
          ..add(_numberField(PasteFieldKey.reportedStandardError, tokens[2]))
          ..add(_numberField(PasteFieldKey.ciLower, tokens[3]))
          ..add(_numberField(PasteFieldKey.ciUpper, tokens[4]))
          ..add(_numberField(PasteFieldKey.reportedT, tokens[5]))
          ..add(_numberField(PasteFieldKey.reportedDegreesOfFreedom, tokens[6]))
          ..add(_numberField(PasteFieldKey.reportedP, tokens[7], pValue: true))
          ..add(_numberField(PasteFieldKey.reportedMeanDifference, tokens[0]));
        break;
      }
    }

    if (statFields.isEmpty && resultFields.isEmpty) {
      return null;
    }

    return _finish(
      input: input,
      candidates: [
        PasteTTestCandidate(
          kind: TTestKind.pairedSamples,
          label: 'Paired samples',
          fields: [
            ...statFields,
            ...resultFields,
            ?_confidenceLevelField(input),
          ],
          reportedPValueTail: _tailFromContext(input, input),
          selectedByText: true,
          format: 'SPSS paired-samples t-test',
          confidence: 0.94,
        ),
      ],
    );
  }

  static TTestPasteParseResult? _parseSpssOneSample(
    String input,
    List<_Line> lines,
  ) {
    if (!_containsFolded(input, 'one-sample test') &&
        !_containsFolded(input, 'one-sample statistics')) {
      return null;
    }

    final statFields = _extractSpssGroupRows(
      lines,
      startMarkers: const ['one-sample statistics'],
      endMarkers: const ['one-sample test'],
      order: _GroupRowOrder.nMeanSd,
      confidence: 0.93,
      captureFourthAsStandardError: true,
    );
    final resultFields = <PasteExtractedField<Object>>[];
    final testValue = _testValueField(input);
    final testStart = _lineIndexContaining(lines, 'one-sample test');
    if (testStart != -1) {
      for (var i = testStart + 1; i < lines.length; i += 1) {
        final line = lines[i];
        if (_isHeaderLike(line)) {
          continue;
        }
        final tokens = _dataNumbersInLine(line);
        if (tokens.length < 6) {
          continue;
        }
        resultFields
          ..add(_numberField(PasteFieldKey.reportedT, tokens[0]))
          ..add(_numberField(PasteFieldKey.reportedDegreesOfFreedom, tokens[1]))
          ..add(_numberField(PasteFieldKey.reportedP, tokens[2], pValue: true))
          ..add(_numberField(PasteFieldKey.reportedMeanDifference, tokens[3]))
          ..add(_numberField(PasteFieldKey.ciLower, tokens[4]))
          ..add(_numberField(PasteFieldKey.ciUpper, tokens[5]));
        break;
      }
    }

    if (statFields.isEmpty && resultFields.isEmpty && testValue == null) {
      return null;
    }

    return _finish(
      input: input,
      candidates: [
        PasteTTestCandidate(
          kind: TTestKind.oneSample,
          label: 'One sample',
          fields: [
            ...statFields,
            ?testValue,
            ...resultFields,
            ?_confidenceLevelField(input),
          ],
          reportedPValueTail: _tailFromContext(input, input),
          selectedByText: true,
          format: 'SPSS one-sample t-test',
          confidence: 0.94,
        ),
      ],
    );
  }

  static TTestPasteParseResult? _parseApa(String input, List<_Line> lines) {
    final tFields = _apaTFields(input);
    if (tFields == null) {
      return null;
    }

    final groupStats = _parenthesizedGroupStats(input);
    final commonFields = <PasteExtractedField<Object>>[
      ...tFields,
      ..._apaPFields(input),
      ..._ciFields(input),
      ?_confidenceLevelField(input),
      ?_testValueField(input),
      ..._referenceMeanFields(input),
      ..._differenceFields(input),
    ];

    if (groupStats.isNotEmpty) {
      commonFields.addAll(_statsToFields(groupStats, _GroupRowOrder.nMeanSd));
    }

    final kind = _apaKind(input, groupStats, commonFields);
    final tail = _tailFromContext(input, input);
    if (kind != null) {
      return _finish(
        input: input,
        candidates: [
          PasteTTestCandidate(
            kind: kind,
            label: _kindLabel(kind),
            fields: commonFields,
            reportedPValueTail: tail,
            selectedByText: true,
            format: 'APA-style sentence',
            confidence: 0.82,
          ),
        ],
      );
    }

    if (groupStats.length >= 2) {
      return _finish(
        input: input,
        candidates: [
          PasteTTestCandidate(
            kind: TTestKind.independentStudent,
            label: 'Independent Student candidate',
            fields: commonFields,
            reportedPValueTail: tail,
            format: 'APA-style sentence',
            confidence: 0.66,
          ),
          PasteTTestCandidate(
            kind: TTestKind.independentWelch,
            label: 'Independent Welch candidate',
            fields: commonFields,
            reportedPValueTail: tail,
            format: 'APA-style sentence',
            confidence: 0.66,
          ),
        ],
        ambiguities: const [
          PasteAmbiguity(
            id: 'apa.independent_kind',
            message:
                'The sentence reports an independent-samples t test without '
                'saying whether it is Student or Welch.',
            candidateLabels: [
              'Independent Student candidate',
              'Independent Welch candidate',
            ],
          ),
        ],
      );
    }

    return _finish(
      input: input,
      candidates: [
        PasteTTestCandidate(
          kind: TTestKind.independentWelch,
          label: 'Welch candidate from non-integer df',
          fields: commonFields,
          reportedPValueTail: tail,
          selectedByText: true,
          format: 'APA-style sentence',
          confidence: 0.55,
        ),
      ],
      ambiguities: const [
        PasteAmbiguity(
          id: 'apa.incomplete_context',
          message:
              'The sentence has t/df/p evidence but not enough design '
              'context to generate a report.',
        ),
      ],
    );
  }

  static TTestPasteParseResult? _parseKeyValue(
    String input,
    List<_Line> lines,
  ) {
    final folded = _fold(input);
    if (!RegExp(r'\bt\s*[:=]').hasMatch(folded) ||
        !RegExp(r'\b(df|degrees of freedom)\s*[:=]').hasMatch(folded)) {
      return null;
    }

    final groupRows = _looseGroupRows(lines);
    final fields = <PasteExtractedField<Object>>[
      ..._statsToFields(groupRows, _GroupRowOrder.nMeanSd),
      ..._keyNumberFields(input),
      ..._ciFields(input),
      ?_confidenceLevelField(input),
      ?_testValueField(input),
      ..._referenceMeanFields(input),
    ];
    final kind = _keyValueKind(input, groupRows);
    if (kind == null) {
      return null;
    }

    return _finish(
      input: input,
      candidates: [
        PasteTTestCandidate(
          kind: kind,
          label: _kindLabel(kind),
          fields: fields,
          reportedPValueTail: _tailFromContext(input, input),
          selectedByText: true,
          format: 'simple key-value/tabular text',
          confidence: 0.75,
        ),
      ],
    );
  }

  static TTestPasteParseResult _finish({
    required String input,
    required List<PasteTTestCandidate> candidates,
    List<PasteAmbiguity> ambiguities = const [],
    List<String> refusalReasons = const [],
  }) {
    final mutableAmbiguities = [...ambiguities];
    for (final candidate in candidates) {
      if (candidate.field(PasteFieldKey.reportedP) != null &&
          candidate.reportedPValueTail == null) {
        mutableAmbiguities.add(
          const PasteAmbiguity(
            id: 'p.tail.unknown',
            message:
                'The p-value was found, but the pasted text does not state '
                'whether it is one-tailed or two-tailed.',
            fieldKeys: [PasteFieldKey.reportedP],
          ),
        );
        break;
      }
      if (candidate.reportedPValueTail ==
          ReportedPValueTail.oneTailedObservedDirection) {
        mutableAmbiguities.add(
          const PasteAmbiguity(
            id: 'p.tail.direction',
            message:
                'The text says one-sided p but does not state lower-tail or '
                'upper-tail direction.',
            fieldKeys: [PasteFieldKey.reportedP],
          ),
        );
        break;
      }
    }

    final selected = candidates.where((candidate) => candidate.selectedByText);
    final selectedCandidate = selected.length == 1 ? selected.single : null;
    final missing = selectedCandidate == null
        ? _unionMissing(candidates)
        : selectedCandidate.missingRequiredFields();
    final status = candidates.isEmpty
        ? PasteParseStatus.cannotParse
        : mutableAmbiguities.isEmpty &&
              selectedCandidate != null &&
              missing.isEmpty
        ? PasteParseStatus.confident
        : PasteParseStatus.needsConfirmation;
    final kind = status == PasteParseStatus.confident
        ? selectedCandidate!.kind
        : _singleKnownKind(candidates, mutableAmbiguities);

    return TTestPasteParseResult(
      input: input,
      status: status,
      detectedTestKind: kind,
      candidates: candidates,
      fields: _uniqueFields(candidates.expand((candidate) => candidate.fields)),
      ambiguities: mutableAmbiguities,
      missingRequiredFields: missing,
      refusalReasons: refusalReasons,
    );
  }

  static TTestPasteParseResult? _earlyRefusal(String input) {
    if (input.trim().isEmpty) {
      return _cannotParse(input, const ['Input is empty.']);
    }
    final folded = _fold(input);
    if (RegExp(
      r'\b(chi-square|chi square|pearson chi-square)\b',
    ).hasMatch(folded)) {
      return _cannotParse(input, const ['Chi-square output is not supported.']);
    }
    if (RegExp(r'\b(anova|analysis of variance)\b').hasMatch(folded)) {
      return _cannotParse(input, const ['ANOVA output is not supported.']);
    }
    if (RegExp(
      r'\b(void main|class\s+\w+|function\s+\w+|import\s+package:)\b',
    ).hasMatch(folded)) {
      return _cannotParse(input, const [
        'Code snippets are not statistical output.',
      ]);
    }
    if (_looksLikeRawData(input) && !RegExp(r'\bt\s*[\(=]').hasMatch(folded)) {
      return _cannotParse(input, const [
        'Raw data table detected; paste parsing expects statistical output.',
      ]);
    }
    return null;
  }

  static TTestPasteParseResult _cannotParse(
    String input,
    List<String> reasons,
  ) {
    return TTestPasteParseResult(
      input: input,
      status: PasteParseStatus.cannotParse,
      detectedTestKind: null,
      candidates: const [],
      fields: const [],
      ambiguities: const [],
      missingRequiredFields: const [],
      refusalReasons: reasons,
    );
  }

  static List<PasteExtractedField<Object>> _extractSpssGroupRows(
    List<_Line> lines, {
    required List<String> startMarkers,
    required List<String> endMarkers,
    required _GroupRowOrder order,
    required double confidence,
    bool dropPairOrdinal = false,
    bool captureFourthAsStandardError = false,
  }) {
    final start = _lineIndexContainingAny(lines, startMarkers);
    if (start == -1) {
      return const [];
    }

    final rows = <_GroupRow>[];
    for (var i = start + 1; i < lines.length; i += 1) {
      final line = lines[i];
      if (_lineContainsAny(line, endMarkers)) {
        break;
      }
      if (_isHeaderLike(line) || line.text.trim().isEmpty) {
        continue;
      }
      final tokens = _dataNumbersInLine(line, dropPairOrdinal: dropPairOrdinal);
      if (tokens.length < 3) {
        continue;
      }
      final label = _labelBefore(line, tokens.first);
      if (label == null) {
        continue;
      }
      rows.add(_GroupRow(label: label, tokens: tokens));
      if (rows.length == 2) {
        break;
      }
    }

    final fields = _statsToFields(rows, order, confidence: confidence);
    if (captureFourthAsStandardError &&
        rows.isNotEmpty &&
        rows.first.tokens.length >= 4) {
      fields.add(
        _numberField(
          PasteFieldKey.reportedStandardError,
          rows.first.tokens[3],
          confidence: confidence,
        ),
      );
    }
    return fields;
  }

  static List<PasteExtractedField<Object>> _statsToFields(
    List<_GroupRow> rows,
    _GroupRowOrder order, {
    double confidence = 0.82,
  }) {
    if (rows.isEmpty) {
      return const [];
    }
    final fields = <PasteExtractedField<Object>>[];
    void addRow(_GroupRow row, bool primary) {
      final labelKey = primary
          ? PasteFieldKey.primaryLabel
          : PasteFieldKey.secondaryLabel;
      final nKey = primary ? PasteFieldKey.primaryN : PasteFieldKey.secondaryN;
      final meanKey = primary
          ? PasteFieldKey.primaryMean
          : PasteFieldKey.secondaryMean;
      final sdKey = primary
          ? PasteFieldKey.primaryStandardDeviation
          : PasteFieldKey.secondaryStandardDeviation;
      final nIndex = order == _GroupRowOrder.nMeanSd ? 0 : 1;
      final meanIndex = order == _GroupRowOrder.nMeanSd ? 1 : 0;
      final sdIndex = 2;
      fields
        ..add(
          PasteExtractedField<Object>(
            key: labelKey,
            value: row.label.value,
            sourceText: row.label.sourceText,
            start: row.label.start,
            end: row.label.end,
            confidence: confidence,
          ),
        )
        ..add(
          _numberField(
            nKey,
            row.tokens[nIndex],
            confidence: confidence,
            preferInteger: true,
          ),
        )
        ..add(
          _numberField(meanKey, row.tokens[meanIndex], confidence: confidence),
        )
        ..add(_numberField(sdKey, row.tokens[sdIndex], confidence: confidence));
    }

    addRow(rows[0], true);
    if (rows.length > 1) {
      addRow(rows[1], false);
    }
    return fields;
  }

  static List<_GroupRow> _parenthesizedGroupStats(String input) {
    final pattern = RegExp(
      '([A-Za-z][^()\\n;]{0,70}?)\\s*\\(\\s*n\\s*=\\s*'
      '($_numberPattern)\\s*,\\s*(?:m|mean)\\s*=\\s*'
      '($_numberPattern)\\s*,\\s*(?:sd|std\\.?\\s*deviation)\\s*=\\s*'
      '($_numberPattern)\\s*\\)',
      caseSensitive: false,
    );
    final rows = <_GroupRow>[];
    for (final match in pattern.allMatches(input)) {
      final label = _trimmedSpan(
        input,
        match.start,
        match.start + match.group(1)!.length,
      );
      rows.add(
        _GroupRow(
          label: label,
          tokens: [
            _tokenFromMatch(input, match, 2),
            _tokenFromMatch(input, match, 3),
            _tokenFromMatch(input, match, 4),
          ],
        ),
      );
      if (rows.length == 2) {
        break;
      }
    }
    return rows;
  }

  static List<_GroupRow> _looseGroupRows(List<_Line> lines) {
    final rows = <_GroupRow>[];
    for (var i = 0; i < lines.length; i += 1) {
      final header = lines[i].folded;
      if (!header.contains('mean') ||
          !header.contains('n') ||
          !(header.contains('std') || header.contains('sd'))) {
        continue;
      }
      for (var j = i + 1; j < lines.length; j += 1) {
        final line = lines[j];
        if (line.text.trim().isEmpty) {
          break;
        }
        if (_isHeaderLike(line)) {
          continue;
        }
        final tokens = _dataNumbersInLine(line);
        if (tokens.length < 3) {
          continue;
        }
        final label = _labelBefore(line, tokens.first);
        if (label == null) {
          continue;
        }
        rows.add(_GroupRow(label: label, tokens: tokens));
        if (rows.length == 2) {
          return rows;
        }
      }
    }
    return rows;
  }

  static List<PasteExtractedField<Object>>? _apaTFields(String input) {
    final pattern = RegExp(
      '\\bt\\s*\\(\\s*($_numberPattern)\\s*\\)\\s*=\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    return [
      _numberField(
        PasteFieldKey.reportedDegreesOfFreedom,
        _tokenFromMatch(input, match, 1),
      ),
      _numberField(PasteFieldKey.reportedT, _tokenFromMatch(input, match, 2)),
    ];
  }

  static List<PasteExtractedField<Object>> _apaPFields(String input) {
    final pattern = RegExp(
      '\\bp(?:[-\\s]?value)?(?:\\s*\\([^)]*\\))?\\s*'
      '(<=|>=|<|>|=|\\u2264|\\u2265)\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(input);
    if (match == null) {
      return const [];
    }
    return [
      _numberField(
        PasteFieldKey.reportedP,
        _tokenFromMatch(input, match, 2),
        relation: _relationFromSymbol(match.group(1)),
        pValue: true,
      ),
    ];
  }

  static List<PasteExtractedField<Object>> _ciFields(String input) {
    final fields = <PasteExtractedField<Object>>[];
    final pattern = RegExp(
      '(?:\\d{1,3}\\s*%\\s*)?(?:ci|confidence interval)'
      '(?:[^\\[]*)\\[\\s*($_numberPattern)\\s*,\\s*($_numberPattern)\\s*\\]',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(input);
    if (match != null) {
      fields
        ..add(
          _numberField(PasteFieldKey.ciLower, _tokenFromMatch(input, match, 1)),
        )
        ..add(
          _numberField(PasteFieldKey.ciUpper, _tokenFromMatch(input, match, 2)),
        );
    }
    return fields;
  }

  static List<PasteExtractedField<Object>> _differenceFields(String input) {
    final fields = <PasteExtractedField<Object>>[];
    final diffPattern = RegExp(
      '(?:paired\\s+)?(?:mean\\s+difference|m\\s*diff|mdiff|difference\\s+mean)'
      '\\s*[:=]\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final diff = diffPattern.firstMatch(input);
    if (diff != null) {
      final token = _tokenFromMatch(input, diff, 1);
      fields
        ..add(_numberField(PasteFieldKey.pairedMeanDifference, token))
        ..add(_numberField(PasteFieldKey.reportedMeanDifference, token));
    }
    final sdPattern = RegExp(
      '(?:sd\\s*diff|sddiff|difference\\s+sd|sd\\s+of\\s+differences)'
      '\\s*[:=]\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final sd = sdPattern.firstMatch(input);
    if (sd != null) {
      fields.add(
        _numberField(
          PasteFieldKey.pairedDifferenceStandardDeviation,
          _tokenFromMatch(input, sd, 1),
        ),
      );
    }
    final sePattern = RegExp(
      '(?:standard\\s+error(?:\\s+difference)?|se(?:\\s+difference)?)'
      '\\s*[:=]\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final se = sePattern.firstMatch(input);
    if (se != null) {
      fields.add(
        _numberField(
          PasteFieldKey.reportedStandardError,
          _tokenFromMatch(input, se, 1),
        ),
      );
    }
    return fields;
  }

  static List<PasteExtractedField<Object>> _referenceMeanFields(String input) {
    final pattern = RegExp(
      '(?:reference\\s+mean|reference\\s+value|test\\s+value|compared\\s+with|against)'
      '\\s*(?:of|=|:)?\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(input);
    if (match == null) {
      return const [];
    }
    return [
      _numberField(
        PasteFieldKey.referenceMean,
        _tokenFromMatch(input, match, 1),
      ),
    ];
  }

  static List<PasteExtractedField<Object>> _keyNumberFields(String input) {
    final fields = <PasteExtractedField<Object>>[];
    void addFirst(PasteFieldKey key, RegExp pattern, {bool pValue = false}) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        return;
      }
      final relation = match.groupCount >= 2
          ? _relationFromSymbol(match.group(1))
          : null;
      final tokenGroup = match.groupCount >= 2 ? 2 : 1;
      fields.add(
        _numberField(
          key,
          _tokenFromMatch(input, match, tokenGroup),
          relation: relation,
          pValue: pValue,
        ),
      );
    }

    addFirst(
      PasteFieldKey.reportedT,
      RegExp('\\bt\\s*[:=]\\s*($_numberPattern)', caseSensitive: false),
    );
    addFirst(
      PasteFieldKey.reportedDegreesOfFreedom,
      RegExp(
        '\\b(?:df|degrees\\s+of\\s+freedom)\\s*[:=]\\s*($_numberPattern)',
        caseSensitive: false,
      ),
    );
    addFirst(
      PasteFieldKey.reportedP,
      RegExp(
        '\\bp(?:[-\\s]?(?:value))?(?:\\s*\\([^)]*\\))?\\s*'
        '(<=|>=|<|>|=|\\u2264|\\u2265)'
        '\\s*($_numberPattern)',
        caseSensitive: false,
      ),
      pValue: true,
    );
    addFirst(
      PasteFieldKey.reportedMeanDifference,
      RegExp(
        '\\bmean\\s+difference\\s*[:=]\\s*($_numberPattern)',
        caseSensitive: false,
      ),
    );
    addFirst(
      PasteFieldKey.reportedStandardError,
      RegExp(
        '\\b(?:std\\.?\\s+error\\s+difference|standard\\s+error\\s+difference|se)'
        '\\s*[:=]\\s*($_numberPattern)',
        caseSensitive: false,
      ),
    );
    return fields;
  }

  static PasteExtractedField<Object>? _confidenceLevelField(String input) {
    final percent = RegExp(
      '(\\d{1,3})\\s*%\\s*(?:ci|confidence interval)',
      caseSensitive: false,
    ).firstMatch(input);
    if (percent != null) {
      final token = _tokenFromMatch(input, percent, 1);
      final number = token.number(preferInteger: true);
      return PasteExtractedField<Object>(
        key: PasteFieldKey.confidenceLevel,
        value: PasteNumber(
          value: number.value / 100,
          decimalPlaces: 2,
          relation: number.relation,
        ),
        sourceText: '${token.sourceText}%',
        start: token.start,
        end: token.end + _followingPercentWidth(input, token.end),
        confidence: 0.92,
      );
    }

    final words = RegExp(
      '(\\d{1,3})\\s*percent\\s+confidence interval',
      caseSensitive: false,
    ).firstMatch(input);
    if (words != null) {
      final token = _tokenFromMatch(input, words, 1);
      final number = token.number(preferInteger: true);
      return PasteExtractedField<Object>(
        key: PasteFieldKey.confidenceLevel,
        value: PasteNumber(value: number.value / 100, decimalPlaces: 2),
        sourceText: token.sourceText,
        start: token.start,
        end: token.end,
        confidence: 0.88,
      );
    }
    return null;
  }

  static int _followingPercentWidth(String input, int offset) {
    var index = offset;
    while (index < input.length && input.codeUnitAt(index) == 32) {
      index += 1;
    }
    return index < input.length && input[index] == '%' ? index + 1 - offset : 0;
  }

  static PasteExtractedField<Object>? _testValueField(String input) {
    final pattern = RegExp(
      'test\\s+value\\s*=\\s*($_numberPattern)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    return _numberField(
      PasteFieldKey.referenceMean,
      _tokenFromMatch(input, match, 1),
    );
  }

  static TTestKind? _selectedIndependentKind(String input) {
    final folded = _fold(input);
    if (RegExp(
      r'\b(use|using|used|selected|chosen|report|reported)\b.{0,60}'
      r'(equal variances not assumed|unequal variances|welch)',
    ).hasMatch(folded)) {
      return TTestKind.independentWelch;
    }
    if (RegExp(
      r'\b(use|using|used|selected|chosen|report|reported)\b.{0,60}'
      r'(equal variances assumed|pooled|student)',
    ).hasMatch(folded)) {
      return TTestKind.independentStudent;
    }
    return null;
  }

  static TTestKind? _apaKind(
    String input,
    List<_GroupRow> groupRows,
    List<PasteExtractedField<Object>> fields,
  ) {
    final folded = _fold(input);
    if (RegExp(r'\b(paired|dependent)\b').hasMatch(folded)) {
      return TTestKind.pairedSamples;
    }
    if (RegExp(r'\bone[- ]sample\b').hasMatch(folded) ||
        fields.any((field) => field.key == PasteFieldKey.referenceMean) &&
            groupRows.length == 1) {
      return TTestKind.oneSample;
    }
    if (RegExp(r'\b(welch|unequal variances|not assumed)\b').hasMatch(folded)) {
      return TTestKind.independentWelch;
    }
    if (RegExp(
      r'\b(student|equal variances assumed|pooled)\b',
    ).hasMatch(folded)) {
      return TTestKind.independentStudent;
    }
    final df = fields
        .where((field) => field.key == PasteFieldKey.reportedDegreesOfFreedom)
        .map((field) => field.value)
        .whereType<PasteNumber>()
        .firstOrNull;
    if (groupRows.length >= 2 &&
        df != null &&
        (df.value - df.value.round()).abs() > 1e-9) {
      return TTestKind.independentWelch;
    }
    return null;
  }

  static TTestKind? _keyValueKind(String input, List<_GroupRow> groupRows) {
    final folded = _fold(input);
    if (RegExp(r'\b(paired|dependent)\b').hasMatch(folded)) {
      return TTestKind.pairedSamples;
    }
    if (RegExp(r'\bone[- ]sample\b').hasMatch(folded)) {
      return TTestKind.oneSample;
    }
    if (RegExp(r'\b(welch|unequal variances|not assumed)\b').hasMatch(folded)) {
      return TTestKind.independentWelch;
    }
    if (RegExp(
      r'\b(student|equal variances assumed|pooled)\b',
    ).hasMatch(folded)) {
      return TTestKind.independentStudent;
    }
    if (groupRows.length >= 2) {
      return null;
    }
    return null;
  }

  static ReportedPValueTail? _tailFromContext(String input, String near) {
    final folded = _fold('$near\n$input');
    if (RegExp(
      r'\b(two[- ]sided|two[- ]tailed|2[- ]tailed|sig\.\s*\(2[- ]tailed\))\b',
    ).hasMatch(folded)) {
      return ReportedPValueTail.twoTailed;
    }
    if (RegExp(
      r'\b(lower[- ]tail|left[- ]tail|less[- ]than|one[- ]tailed\s+less)\b',
    ).hasMatch(folded)) {
      return ReportedPValueTail.less;
    }
    if (RegExp(
      r'\b(upper[- ]tail|right[- ]tail|greater[- ]than|one[- ]tailed\s+greater)\b',
    ).hasMatch(folded)) {
      return ReportedPValueTail.greater;
    }
    if (RegExp(
      r'\b(one[- ]sided|one[- ]tailed|1[- ]tailed|sig\.\s*\(1[- ]tailed\))\b',
    ).hasMatch(folded)) {
      return ReportedPValueTail.oneTailedObservedDirection;
    }
    return null;
  }

  static PasteExtractedField<Object> _numberField(
    PasteFieldKey key,
    _NumericToken token, {
    double confidence = 0.90,
    bool preferInteger = false,
    ReportedRelation? relation,
    bool pValue = false,
  }) {
    return PasteExtractedField<Object>(
      key: key,
      value: token.number(
        preferInteger: preferInteger,
        relation: relation,
        pValue: pValue,
      ),
      sourceText: token.sourceText,
      start: token.start,
      end: token.end,
      confidence: confidence,
    );
  }

  static List<_NumericToken> _dataNumbersInLine(
    _Line line, {
    bool dropPairOrdinal = false,
  }) {
    final tokens = _numbersInLine(line);
    if (!dropPairOrdinal || tokens.isEmpty) {
      return tokens;
    }
    final firstValue = tokens.first.number(preferInteger: true).value;
    if (line.folded.trimLeft().startsWith('pair ') && firstValue == 1) {
      return tokens.sublist(1);
    }
    return tokens;
  }

  static List<_NumericToken> _numbersInLine(_Line line, {int startInLine = 0}) {
    final segment = line.text.substring(startInLine);
    return _numberRegex
        .allMatches(segment)
        .map(
          (match) => _NumericToken(
            sourceText: match.group(0)!,
            start: line.start + startInLine + match.start,
            end: line.start + startInLine + match.end,
          ),
        )
        .toList();
  }

  static _NumericToken _tokenFromMatch(
    String input,
    RegExpMatch match,
    int group,
  ) {
    return _NumericToken(
      sourceText: match.group(group)!,
      start: match.start + match.group(0)!.indexOf(match.group(group)!),
      end:
          match.start +
          match.group(0)!.indexOf(match.group(group)!) +
          match.group(group)!.length,
    );
  }

  static _TextSpan? _labelBefore(_Line line, _NumericToken firstToken) {
    final endInLine = firstToken.start - line.start;
    final originalRaw = line.text.substring(0, endInLine);
    final pairPrefix = RegExp(
      r'^\s*Pair\s+\d+\s*',
      caseSensitive: false,
    ).firstMatch(originalRaw);
    final prefixWidth = pairPrefix?.end ?? 0;
    final raw = originalRaw.substring(prefixWidth);
    final startTrim = raw.length - raw.trimLeft().length;
    final endTrim = raw.trimRight().length;
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return _TextSpan(
      value: _cleanLabel(value),
      sourceText: raw.substring(startTrim, endTrim),
      start: line.start + prefixWidth + startTrim,
      end: line.start + prefixWidth + endTrim,
    );
  }

  static _TextSpan _trimmedSpan(String input, int start, int end) {
    final source = input.substring(start, end);
    final left = source.length - source.trimLeft().length;
    final right = source.trimRight().length;
    return _TextSpan(
      value: _cleanLabel(source.substring(left, right)),
      sourceText: source.substring(left, right),
      start: start + left,
      end: start + right,
    );
  }

  static ReportedRelation _relationFromSymbol(String? symbol) {
    return switch (symbol?.trim()) {
      '<' => ReportedRelation.lessThan,
      '<=' => ReportedRelation.lessThanOrEqual,
      '\u2264' => ReportedRelation.lessThanOrEqual,
      '>' => ReportedRelation.greaterThan,
      '>=' => ReportedRelation.greaterThanOrEqual,
      '\u2265' => ReportedRelation.greaterThanOrEqual,
      _ => ReportedRelation.equalRounded,
    };
  }

  static List<PasteMissingField> _unionMissing(
    List<PasteTTestCandidate> candidates,
  ) {
    final seen = <String>{};
    final missing = <PasteMissingField>[];
    for (final candidate in candidates) {
      for (final field in candidate.missingRequiredFields()) {
        final key = field.key?.path ?? field.reason;
        if (seen.add(key)) {
          missing.add(field);
        }
      }
    }
    return missing;
  }

  static List<PasteExtractedField<Object>> _uniqueFields(
    Iterable<PasteExtractedField<Object>> fields,
  ) {
    final seen = <String>{};
    final unique = <PasteExtractedField<Object>>[];
    for (final field in fields) {
      final id = '${field.key.path}:${field.start}:${field.end}';
      if (seen.add(id)) {
        unique.add(field);
      }
    }
    unique.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart == 0 ? a.end.compareTo(b.end) : byStart;
    });
    return unique;
  }

  static TTestKind? _singleKnownKind(
    List<PasteTTestCandidate> candidates,
    List<PasteAmbiguity> ambiguities,
  ) {
    if (candidates.isEmpty ||
        ambiguities.any(
          (item) =>
              item.id.contains('kind') || item.id.contains('variance_row'),
        )) {
      return null;
    }
    final kind = candidates.first.kind;
    return candidates.every((candidate) => candidate.kind == kind)
        ? kind
        : null;
  }

  static String _kindLabel(TTestKind kind) {
    return switch (kind) {
      TTestKind.independentStudent => 'Independent Student',
      TTestKind.independentWelch => 'Independent Welch',
      TTestKind.pairedSamples => 'Paired samples',
      TTestKind.oneSample => 'One sample',
    };
  }

  static bool _looksLikeRawData(String input) {
    final rows = _splitLines(input)
        .where((line) => line.text.trim().isNotEmpty)
        .map((line) => _dataNumbersInLine(line).length)
        .toList();
    if (rows.length < 4) {
      return false;
    }
    final numericRows = rows.where((count) => count >= 2).length;
    return numericRows >= 3 && numericRows >= rows.length - 1;
  }

  static bool _isHeaderLike(_Line line) {
    final folded = line.folded;
    if (folded.trim().isEmpty) {
      return true;
    }
    return folded.contains('mean') ||
        folded.contains('std') ||
        folded.contains('sig.') ||
        folded.contains('confidence interval') ||
        folded.contains('levene') ||
        folded.contains('df') && folded.contains('t');
  }

  static int _lineIndexContaining(List<_Line> lines, String marker) {
    return _lineIndexContainingAny(lines, [marker]);
  }

  static int _lineIndexContainingAny(List<_Line> lines, List<String> markers) {
    for (var i = 0; i < lines.length; i += 1) {
      if (_lineContainsAny(lines[i], markers)) {
        return i;
      }
    }
    return -1;
  }

  static bool _lineContainsAny(_Line line, List<String> markers) {
    return markers.any(line.folded.contains);
  }

  static bool _containsFolded(String input, String marker) {
    return _fold(input).contains(marker);
  }

  static List<_Line> _splitLines(String input) {
    final lines = <_Line>[];
    var start = 0;
    for (final match in RegExp(r'\r\n|\r|\n').allMatches(input)) {
      lines.add(_Line(input.substring(start, match.start), start));
      start = match.end;
    }
    if (start <= input.length) {
      lines.add(_Line(input.substring(start), start));
    }
    return lines;
  }

  static String _fold(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll('\t', ' ')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .toLowerCase();
  }

  static String _cleanLabel(String value) {
    final compact = value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return compact.replaceFirst(
      RegExp(r'^(?:and|or)\s+', caseSensitive: false),
      '',
    );
  }

  static final RegExp _numberRegex = RegExp(_numberPattern);
  static const String _numberPattern =
      r'[\-\u2212\u2013\u2014]?(?:(?:\d{1,3}(?:[,\.\s\u00a0]\d{3})+(?:[,.]\d+)?)|\d+(?:[,.]\d+)?|[,.]\d+)(?!\d|[,.]\d)';
}

enum _GroupRowOrder { nMeanSd, meanNSd }

class _Line {
  const _Line(this.text, this.start);

  final String text;
  final int start;

  String get folded => TTestPasteParser._fold(text);
}

class _NumericToken {
  const _NumericToken({
    required this.sourceText,
    required this.start,
    required this.end,
  });

  final String sourceText;
  final int start;
  final int end;

  PasteNumber number({
    bool preferInteger = false,
    ReportedRelation? relation,
    bool pValue = false,
  }) {
    final parsed = _parseLocaleNumber(sourceText, preferInteger: preferInteger);
    var parsedRelation = relation ?? ReportedRelation.equalRounded;
    var value = parsed.value;
    var roundedZeroP = false;
    if (pValue &&
        parsedRelation == ReportedRelation.equalRounded &&
        value == 0 &&
        parsed.decimalPlaces >= 3 &&
        RegExp(r'^[\-+]?[0,.]*0+$').hasMatch(
          sourceText
              .replaceAll('\u2212', '-')
              .replaceAll('\u2013', '-')
              .replaceAll('\u2014', '-')
              .replaceAll(RegExp(r'\s+'), ''),
        )) {
      value = math.pow(10, -parsed.decimalPlaces).toDouble();
      parsedRelation = ReportedRelation.lessThan;
      roundedZeroP = true;
    }
    return PasteNumber(
      value: value,
      decimalPlaces: parsed.decimalPlaces,
      relation: parsedRelation,
      spssRoundedZeroP: roundedZeroP,
    );
  }
}

class _ParsedNumber {
  const _ParsedNumber({required this.value, required this.decimalPlaces});

  final double value;
  final int decimalPlaces;
}

_ParsedNumber _parseLocaleNumber(String source, {required bool preferInteger}) {
  var text = source
      .trim()
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u2212', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll(RegExp(r'\s+'), '');
  final negative = text.startsWith('-');
  if (negative || text.startsWith('+')) {
    text = text.substring(1);
  }

  final comma = text.lastIndexOf(',');
  final dot = text.lastIndexOf('.');
  String? decimalSeparator;
  if (comma != -1 && dot != -1) {
    decimalSeparator = comma > dot ? ',' : '.';
  } else if (comma != -1) {
    decimalSeparator = preferInteger && _groupedInteger(text, ',') ? null : ',';
  } else if (dot != -1) {
    decimalSeparator = preferInteger && _groupedInteger(text, '.') ? null : '.';
  }

  late String normalized;
  var decimals = 0;
  if (decimalSeparator == null) {
    normalized = text.replaceAll(RegExp(r'[,.]'), '');
  } else {
    final separatorIndex = text.lastIndexOf(decimalSeparator);
    decimals = text.length - separatorIndex - 1;
    final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
    normalized =
        '${text.substring(0, separatorIndex).replaceAll(thousandsSeparator, '')}.'
        '${text.substring(separatorIndex + 1)}';
  }
  if (normalized.startsWith('.')) {
    normalized = '0$normalized';
  }
  if (negative) {
    normalized = '-$normalized';
  }
  return _ParsedNumber(
    value: double.parse(normalized),
    decimalPlaces: decimals,
  );
}

bool _groupedInteger(String text, String separator) {
  final escaped = separator == '.' ? r'\.' : separator;
  return RegExp('^\\d{1,3}($escaped\\d{3})+\$').hasMatch(text);
}

class _TextSpan {
  const _TextSpan({
    required this.value,
    required this.sourceText,
    required this.start,
    required this.end,
  });

  final String value;
  final String sourceText;
  final int start;
  final int end;
}

class _GroupRow {
  const _GroupRow({required this.label, required this.tokens});

  final _TextSpan label;
  final List<_NumericToken> tokens;
}

class _IndependentRow {
  const _IndependentRow({
    required this.kind,
    required this.fields,
    required this.tail,
  });

  final TTestKind kind;
  final List<PasteExtractedField<Object>> fields;
  final ReportedPValueTail? tail;
}
