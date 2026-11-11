import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('crystal_drop.png size: ${image.width}x${image.height}');

  // In crystal_drop.png, let's find where the colored/shaded facet pixels are:
  // Facet pixels have color: either saturation, or difference from the white background.
  // Let's print the contour for every 20 rows from top to bottom
  for (int y = 0; y < image.height; y += 20) {
    int minX = -1, maxX = -1;
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final a = p.a;

      // Check if this is a facet of the droplet
      // A white/background pixel has r > 240, g > 240, b > 245
      // Droplet pixels have color (blues, purples, cyans, magentas, teals)
      final isBg = (r > 238 && g > 238 && b > 242) || a < 20;
      if (!isBg) {
        if (minX == -1) minX = x;
        maxX = x;
      }
    }
    if (minX != -1) {
      print('Y=$y: X=$minX..$maxX, width=${maxX - minX + 1}, mid=${(minX + maxX) / 2}');
    } else {
      print('Y=$y: [EMPTY/BACKGROUND]');
    }
  }
}
