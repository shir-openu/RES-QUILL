// Independent spot-check written by Claude, not by the agent that wrote the parser.
// Runs the parser over the sample files in SAMPLE_UPLOADS\PASTE_TEXT - files the parser
// author never saw - and prints what it extracted.
//
//   dart run tool/verify/claude_check_paste.dart

import 'dart:io';

import 'package:res_quill/src/paste/paste_parser.dart';

const dir = r'D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\SAMPLE_UPLOADS\PASTE_TEXT';

void main() {
  final files = Directory(dir).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final text = file.readAsStringSync();
    stdout.writeln('=== $name (${text.length} chars)');
    try {
      final r = TTestPasteParser.parse(text);
      stdout.writeln('  status: ${r.status}  kind: ${r.detectedTestKind}');
      for (final f in r.fields) {
        stdout.writeln(
          '  field ${f.key} = ${f.value}  [${f.sourceText.trim()}]',
        );
      }
      for (final a in r.ambiguities) {
        stdout.writeln('  AMBIGUITY: ${a.message}');
      }
      for (final m in r.missingRequiredFields) {
        stdout.writeln('  MISSING: ${m.key}');
      }
      for (final why in r.refusalReasons) {
        stdout.writeln('  REFUSED: $why');
      }
    } catch (e) {
      stdout.writeln('  THREW: $e');
    }
    stdout.writeln('');
  }
}
