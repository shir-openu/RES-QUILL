import 'package:flutter/services.dart';

bool get canOpenSamplePasteFolder => false;

Future<String> writeSamplePasteFiles({
  required AssetBundle bundle,
  required Iterable<String> assetPaths,
  String? appDataPath,
}) {
  throw UnsupportedError('Sample folder opening is unavailable.');
}

Future<void> openSamplePasteFolder({
  required AssetBundle bundle,
  required Iterable<String> assetPaths,
}) {
  throw UnsupportedError('Sample folder opening is unavailable.');
}
