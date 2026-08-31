import '../stats/stats.dart';

enum EvidenceProvenance { reportedByUser, recomputedByUs }

extension EvidenceProvenanceName on EvidenceProvenance {
  String get label {
    return switch (this) {
      EvidenceProvenance.reportedByUser => 'reportedByUser',
      EvidenceProvenance.recomputedByUs => 'recomputedByUs',
    };
  }
}

class EvidenceSource {
  const EvidenceSource({
    required this.field,
    required this.provenance,
    this.note,
  });

  final String field;
  final EvidenceProvenance provenance;
  final String? note;

  Map<String, Object?> toJson() {
    return {'field': field, 'provenance': provenance.label, 'note': note};
  }
}

class EvidenceMapEntry {
  const EvidenceMapEntry({
    required this.id,
    required this.section,
    required this.label,
    required this.value,
    required this.formatted,
    required this.source,
    this.relation = '=',
  });

  final String id;
  final String section;
  final String label;
  final double value;
  final String formatted;
  final EvidenceSource source;
  final String relation;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'section': section,
      'label': label,
      'value': value,
      'formatted': formatted,
      'relation': relation,
      'source': source.toJson(),
    };
  }
}

class EvidenceMap {
  const EvidenceMap(this.entries);

  final List<EvidenceMapEntry> entries;

  Map<String, Object> toJson() {
    return {'entries': entries.map((entry) => entry.toJson()).toList()};
  }
}

class EvidenceSourceRegistry {
  EvidenceSourceRegistry([Map<String, EvidenceSource> sources = const {}])
    : _sources = Map.unmodifiable(sources);

  final Map<String, EvidenceSource> _sources;

  EvidenceSource sourceFor(
    String key, {
    EvidenceSource? fallback,
    String? fallbackField,
  }) {
    return _sources[key] ??
        fallback ??
        EvidenceSource(
          field: fallbackField ?? key,
          provenance: EvidenceProvenance.recomputedByUs,
        );
  }

  EvidenceSourceRegistry merge(Map<String, EvidenceSource> sources) {
    return EvidenceSourceRegistry({..._sources, ...sources});
  }

  static EvidenceSourceRegistry fromValidationInput(
    TTestValidationInput input,
  ) {
    final sources = <String, EvidenceSource>{};

    void addDescriptives(String resultPrefix, ReportedDescriptives? values) {
      if (values == null) {
        return;
      }
      if (values.n != null) {
        sources['$resultPrefix.n'] = EvidenceSource(
          field: '${_inputPrefix(resultPrefix)}.n',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
      if (values.mean != null) {
        sources['$resultPrefix.mean'] = EvidenceSource(
          field: '${_inputPrefix(resultPrefix)}.mean',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
      if (values.standardDeviation != null) {
        sources['$resultPrefix.standardDeviation'] = EvidenceSource(
          field: '${_inputPrefix(resultPrefix)}.standardDeviation',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
    }

    if (input.kind == TTestKind.pairedSamples && input.paired != null) {
      addDescriptives('primary', input.paired!.first);
      addDescriptives('secondary', input.paired!.second);
      if (input.paired!.meanDifference != null) {
        sources['pairedDifferences.mean'] = const EvidenceSource(
          field: 'input.paired.meanDifference',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
      if (input.paired!.differenceStandardDeviation != null) {
        sources['pairedDifferences.standardDeviation'] = const EvidenceSource(
          field: 'input.paired.differenceStandardDeviation',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
      if (input.paired!.first.n != null) {
        sources['pairedDifferences.n'] = const EvidenceSource(
          field: 'input.paired.first.n',
          provenance: EvidenceProvenance.reportedByUser,
        );
      }
    } else {
      addDescriptives('primary', input.first);
      addDescriptives('secondary', input.second);
    }

    if (input.referenceMean != null) {
      sources['referenceMean'] = const EvidenceSource(
        field: 'input.referenceMean',
        provenance: EvidenceProvenance.reportedByUser,
      );
    }

    return EvidenceSourceRegistry(sources);
  }

  static EvidenceSourceRegistry independentRaw({
    String firstValuesField = 'input.firstValues',
    String secondValuesField = 'input.secondValues',
  }) {
    return EvidenceSourceRegistry({
      'primary.n': EvidenceSource(
        field: firstValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'primary.mean': EvidenceSource(
        field: firstValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'primary.standardDeviation': EvidenceSource(
        field: firstValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'secondary.n': EvidenceSource(
        field: secondValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'secondary.mean': EvidenceSource(
        field: secondValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'secondary.standardDeviation': EvidenceSource(
        field: secondValuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
    });
  }

  static EvidenceSourceRegistry pairedRaw({
    String firstValuesField = 'input.firstValues',
    String secondValuesField = 'input.secondValues',
  }) {
    return EvidenceSourceRegistry({
      ...independentRaw(
        firstValuesField: firstValuesField,
        secondValuesField: secondValuesField,
      )._sources,
      'pairedDifferences.mean': EvidenceSource(
        field: '$firstValuesField - $secondValuesField',
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'pairedDifferences.standardDeviation': EvidenceSource(
        field: '$firstValuesField - $secondValuesField',
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'pairedDifferences.n': EvidenceSource(
        field: '$firstValuesField and $secondValuesField',
        provenance: EvidenceProvenance.recomputedByUs,
      ),
    });
  }

  static EvidenceSourceRegistry oneSampleRaw({
    String valuesField = 'input.values',
    bool referenceMeanReported = true,
  }) {
    return EvidenceSourceRegistry({
      'primary.n': EvidenceSource(
        field: valuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'primary.mean': EvidenceSource(
        field: valuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      'primary.standardDeviation': EvidenceSource(
        field: valuesField,
        provenance: EvidenceProvenance.recomputedByUs,
      ),
      if (referenceMeanReported)
        'referenceMean': const EvidenceSource(
          field: 'input.referenceMean',
          provenance: EvidenceProvenance.reportedByUser,
        ),
    });
  }

  static String _inputPrefix(String resultPrefix) {
    return switch (resultPrefix) {
      'primary' => 'input.first',
      'secondary' => 'input.second',
      _ => 'input.$resultPrefix',
    };
  }
}
