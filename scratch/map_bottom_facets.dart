import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Mapping true droplet bottom facets:');
  for (int y = 440; y < image.height; y += 5) {
    int left = -1, right = -1;
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      // Droplet facet pixel test:
      // True facets have saturation and are NOT the near-white background (r,g,b > 228)
      final isFacet = !(p.r > 225 && p.g > 225 && p.b > 225);
      if (isFacet) {
        if (left == -1) left = x;
        right = x;
      }
    }
    if (left != -1) {
      print('Y=$y: left=$left, right=$right, width=${right - left + 1}, center=${(left + right) / 2}');
    } else {
      print('Y=$y: NO FACETS');
    }
  }
}
