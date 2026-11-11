import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Mapping app_logo.png bottom droplet:');
  for (int y = 750; y <= 845; y += 5) {
    int left = -1, right = -1;
    for (int x = 200; x < 820; x++) {
      final p = image.getPixel(x, y);
      final isFacet = !(p.r > 240 && p.g > 240 && p.b > 240);
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
