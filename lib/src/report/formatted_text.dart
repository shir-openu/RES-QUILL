import '../stats/numeric.dart';

class ReportTextRun {
  const ReportTextRun(this.text, {this.italic = false});

  final String text;
  final bool italic;

  Map<String, Object> toJson() {
    return {'text': text, 'italic': italic};
  }
}

class ReportText {
  const ReportText(this.runs);

  final List<ReportTextRun> runs;

  String get plainText => runs.map((run) => run.text).join();

  String get markedUpText {
    return runs
        .map((run) => run.italic ? '<i>${run.text}</i>' : run.text)
        .join();
  }

  Map<String, Object> toJson() {
    return {
      'plainText': plainText,
      'markedUpText': markedUpText,
      'runs': runs.map((run) => run.toJson()).toList(),
    };
  }
}

class ReportTextBuilder {
  final List<ReportTextRun> _runs = [];

  void add(String text) {
    if (text.isEmpty) {
      return;
    }
    if (_runs.isNotEmpty && !_runs.last.italic) {
      final previous = _runs.removeLast();
      _runs.add(ReportTextRun(previous.text + text));
      return;
    }
    _runs.add(ReportTextRun(text));
  }

  void italic(String text) {
    if (text.isEmpty) {
      return;
    }
    if (_runs.isNotEmpty && _runs.last.italic) {
      final previous = _runs.removeLast();
      _runs.add(ReportTextRun(previous.text + text, italic: true));
      return;
    }
    _runs.add(ReportTextRun(text, italic: true));
  }

  ReportText build() => ReportText(List.unmodifiable(_runs));
}

class FormattedNumber {
  const FormattedNumber({
    required this.value,
    required this.text,
    this.relation = '=',
  });

  final double value;
  final String text;
  final String relation;

  String get display => '$relation $text';
}

class ApaNumberFormat {
  const ApaNumberFormat._();

  static String value(double value, {int decimals = 2}) {
    requireFinite(value, 'value');
    return _fixed(value, decimals);
  }

  static String df(double value, {required bool welch}) {
    requireFinite(value, 'degrees of freedom');
    return welch ? _fixed(value, 2) : value.round().toString();
  }

  static String p(double value, {int decimals = 3}) {
    return pValue(value, decimals: decimals).display;
  }

  static FormattedNumber pValue(double value, {int decimals = 3}) {
    requireProbability(value, 'p-value');
    if (value < 0.001) {
      return FormattedNumber(
        value: value,
        text: _omitLeadingZero(_fixed(0.001, 3)),
        relation: '<',
      );
    }
    return FormattedNumber(
      value: value,
      text: _omitLeadingZero(_fixed(value, decimals)),
    );
  }

  static String probability(double value, {int decimals = 3}) {
    requireProbability(value, 'probability');
    return _omitLeadingZero(_fixed(value, decimals));
  }

  static String correlation(double value, {int decimals = 2}) {
    if (value < -1 || value > 1) {
      throw StatsException('correlation must be in [-1, 1].');
    }
    return _omitLeadingZero(_fixed(value, decimals));
  }

  static String percent(double value, {int decimals = 0}) {
    requireProbability(value, 'percentage source');
    return '${_fixed(value * 100, decimals)}%';
  }

  static String _fixed(double value, int decimals) {
    if (decimals < 0) {
      throw StatsException('decimals must be non-negative.');
    }
    final halfUnit = 0.5 * _pow10(-decimals);
    final normalized = value.abs() < halfUnit ? 0.0 : value;
    return normalized.toStringAsFixed(decimals);
  }

  static String _omitLeadingZero(String text) {
    if (text.startsWith('0.')) {
      return text.substring(1);
    }
    if (text.startsWith('-0.')) {
      return '-.${text.substring(3)}';
    }
    return text;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    if (exponent >= 0) {
      for (var i = 0; i < exponent; i += 1) {
        result *= 10;
      }
      return result;
    }
    for (var i = 0; i < -exponent; i += 1) {
      result /= 10;
    }
    return result;
  }
}
