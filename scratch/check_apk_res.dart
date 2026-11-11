import 'dart:io';
import 'package:archive/archive_io.dart';

void main() {
  final file = File('levels_v4/levels_v4.apk');
  final bytes = file.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  print('Total files in APK: ${archive.files.length}');
  final resEntries = archive.files.where((f) => f.name.startsWith('res/')).take(30);
  for (final f in resEntries) {
    print('  ${f.name} (${f.size} bytes)');
  }
}
