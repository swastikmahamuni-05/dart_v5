import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('app_logo.png: ${image.width}x${image.height}, channels: ${image.numChannels}, hasAlpha: ${image.hasAlpha}');
  // Sample pixels at the 4 corners
  print('(0,0): ${image.getPixel(0, 0)}');
  print('(1023,0): ${image.getPixel(1023, 0)}');
  print('(0,1023): ${image.getPixel(0, 1023)}');
  print('(1023,1023): ${image.getPixel(1023, 1023)}');
}
