import 'dart:io';

import 'package:flutter/services.dart';

bool get canOpenSamplePasteFolder {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

Future<void> openSamplePasteFolder({
  required AssetBundle bundle,
  required Iterable<String> assetPaths,
}) async {
  if (!canOpenSamplePasteFolder) {
    throw UnsupportedError('Sample folder opening is unavailable.');
  }
  final directoryPath = await writeSamplePasteFiles(
    bundle: bundle,
    assetPaths: assetPaths,
  );
  await _openDirectory(Directory(directoryPath));
}

Future<String> writeSamplePasteFiles({
  required AssetBundle bundle,
  required Iterable<String> assetPaths,
  String? appDataPath,
}) async {
  final directory = _samplePasteDirectory(appDataPath);
  await directory.create(recursive: true);
  for (final assetPath in assetPaths) {
    final assetBytes = await _assetBytes(bundle, assetPath);
    final fileName = Uri.parse(assetPath).pathSegments.last;
    final file = File(_join(directory.path, fileName));
    if (!await file.exists() ||
        !_sameBytes(await file.readAsBytes(), assetBytes)) {
      await file.writeAsBytes(assetBytes, flush: true);
    }
  }
  return directory.path;
}

Directory _samplePasteDirectory(String? appDataPath) {
  final appData = appDataPath == null
      ? _appDataDirectory()
      : Directory(appDataPath);
  return Directory(_join(appData.path, 'sample_paste_text'));
}

Directory _appDataDirectory() {
  if (Platform.isWindows) {
    final base =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        _join(Platform.environment['USERPROFILE'] ?? '.', 'AppData', 'Roaming');
    return Directory(_join(base, 'Res-Quill'));
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '.';
    return Directory(
      _join(home, 'Library', 'Application Support', 'Res-Quill'),
    );
  }
  final dataHome =
      Platform.environment['XDG_DATA_HOME'] ??
      _join(Platform.environment['HOME'] ?? '.', '.local', 'share');
  return Directory(_join(dataHome, 'res-quill'));
}

Future<Uint8List> _assetBytes(AssetBundle bundle, String assetPath) async {
  final data = await bundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _openDirectory(Directory directory) async {
  if (Platform.isWindows) {
    await Process.start('explorer.exe', [
      directory.path,
    ], mode: ProcessStartMode.detached);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', [
      directory.path,
    ], mode: ProcessStartMode.detached);
    return;
  }
  await Process.start('xdg-open', [
    directory.path,
  ], mode: ProcessStartMode.detached);
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

String _join(String first, String second, [String? third, String? fourth]) {
  final parts = [first, second, ?third, ?fourth];
  final separator = Platform.pathSeparator;
  var path = '';
  for (final part in parts.where((part) => part.isNotEmpty)) {
    if (path.isEmpty) {
      path = part;
    } else if (path.endsWith('/') || path.endsWith('\\')) {
      path = '$path$part';
    } else {
      path = '$path$separator$part';
    }
  }
  return path;
}
