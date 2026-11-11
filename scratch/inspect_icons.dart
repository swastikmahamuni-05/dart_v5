import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final files = [
    'assets/icon/crystal_drop.png',
    'assets/icon/app_logo.png',
    'assets/icon/app_logo.jpg',
    'assets/icon/app_icon.png',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      print('$path does not exist');
      continue;
    }
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      print('$path failed to decode');
    } else {
      print('$path: ${decoded.width}x${decoded.height}, numChannels=${decoded.numChannels}, hasAlpha=${decoded.hasAlpha}');
    }
  }
}
