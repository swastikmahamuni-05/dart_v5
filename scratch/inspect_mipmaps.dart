import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final mipmaps = [
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
  ];

  for (final path in mipmaps) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final image = img.decodeImage(file.readAsBytesSync())!;
    print('$path: ${image.width}x${image.height}');
  }
}
