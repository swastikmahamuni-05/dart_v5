import 'dart:io';
import 'package:archive/archive_io.dart';

void main() {
  final file = File('levels_v4/levels_v4.apk');
  if (!file.existsSync()) {
    print('APK file does not exist');
    return;
  }

  print('Verifying APK contents: ${file.path} (${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB)');

  final bytes = file.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  final iconFiles = <String>[];
  for (final entity in archive.files) {
    if (entity.name.contains('ic_launcher') || entity.name.contains('crystal_drop')) {
      iconFiles.add('${entity.name} (${entity.size} bytes)');
    }
  }

  print('Matched icon resources in APK:');
  for (final icon in iconFiles) {
    print('  - $icon');
  }
}
