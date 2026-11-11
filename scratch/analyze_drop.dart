import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Size: ${image.width}x${image.height}');
  
  // Check corner pixels
  print('Top-left pixel: ${image.getPixel(0, 0)} (a=${image.getPixel(0, 0).a})');
  print('Top-right pixel: ${image.getPixel(image.width - 1, 0)} (a=${image.getPixel(image.width - 1, 0).a})');
  print('Bottom-left pixel: ${image.getPixel(0, image.height - 1)} (a=${image.getPixel(0, image.height - 1).a})');
  print('Center pixel: ${image.getPixel(image.width ~/ 2, image.height ~/ 2)} (a=${image.getPixel(image.width ~/ 2, image.height ~/ 2).a})');

  // Let's find bounding box where pixel is not white and not transparent
  int minX = image.width, maxX = 0, minY = image.height, maxY = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final a = p.a;

      // Check if pixel is part of the drop (not transparent and not pure white)
      final isWhite = (r > 248 && g > 248 && b > 248);
      final isTransparent = a < 20;

      if (!isTransparent && !isWhite) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Drop bounding box: X: $minX..$maxX (${maxX - minX + 1}px), Y: $minY..$maxY (${maxY - minY + 1}px)');
}
