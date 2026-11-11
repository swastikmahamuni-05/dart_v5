import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Image dimensions: ${image.width}x${image.height}');

  int transparentPixels = 0;
  int nearWhitePixels = 0;
  int solidColorPixels = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.a == 0) {
        transparentPixels++;
      } else if (p.r > 240 && p.g > 240 && p.b > 240) {
        nearWhitePixels++;
      } else {
        solidColorPixels++;
      }
    }
  }

  print('Transparent pixels: $transparentPixels');
  print('Near white pixels: $nearWhitePixels');
  print('Solid colored drop pixels: $solidColorPixels');
}
