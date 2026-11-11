import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('App logo size: ${image.width}x${image.height}');

  // Find the drop in app_logo.png:
  // The drop has colorful pixels (saturation > 0.2 or blue/cyan/purple hues)
  int minX = image.width, maxX = 0, minY = image.height, maxY = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;

      // Drop colors are vibrant (cyan, purple, blue)
      // Check if pixel is distinctively colorful (not gray/white of background or dark gray of text)
      // Drop has max(r,g,b) - min(r,g,b) > 40 and b > 100
      final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
      if ((maxC - minC) > 30 && (b > 100 || g > 100)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Detected drop region in app_logo.png:');
  print('X: $minX..$maxX (${maxX - minX + 1}px)');
  print('Y: $minY..$maxY (${maxY - minY + 1}px)');
  print('Center of drop: (${(minX + maxX) / 2}, ${(minY + maxY) / 2})');
  print('Image center: (${image.width / 2}, ${image.height / 2})');
}
