import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final original = img.decodeImage(file.readAsBytesSync())!;

  print('Testing facet detection on app_logo.png:');
  for (int y = 780; y <= 842; y += 4) {
    int left = -1, right = -1;
    for (int x = 265; x <= 760; x++) {
      final p = original.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
      final avgC = (r + g + b) / 3.0;

      // Facet pixel condition:
      // Real facet pixels have either saturation (maxC - minC >= 10) OR darkness (avgC <= 235)
      final isFacet = (maxC - minC >= 10) || avgC <= 235;

      if (isFacet) {
        if (left == -1) left = x;
        right = x;
      }
    }
    if (left != -1) {
      print('Y=$y: left=$left, right=$right (width=${right - left + 1}, center=${(left + right) / 2})');
    } else {
      print('Y=$y: NO FACETS');
    }
  }
}
