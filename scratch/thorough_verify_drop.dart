import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Verifying assets/icon/crystal_drop.png: ${image.width}x${image.height}');

  // 1. Corners check
  assert(image.getPixel(0, 0).a == 0, 'Top-left must be transparent');
  assert(image.getPixel(image.width - 1, 0).a == 0, 'Top-right must be transparent');
  assert(image.getPixel(0, image.height - 1).a == 0, 'Bottom-left must be transparent');
  assert(image.getPixel(image.width - 1, image.height - 1).a == 0, 'Bottom-right must be transparent');

  print('Corners verified: 100% transparent.');

  // 2. Check contour from top to bottom
  print('Droplet contour scan:');
  for (int y = 0; y < image.height; y += 30) {
    int left = -1, right = -1;
    for (int x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a > 20) {
        if (left == -1) left = x;
        right = x;
      }
    }
    if (left != -1) {
      final w = right - left + 1;
      final mid = (left + right) / 2.0;
      print('Y=$y: left=$left, right=$right (width=$w, center=$mid)');
    } else {
      print('Y=$y: [TRANSPARENT PADDING]');
    }
  }

  // Check the last 15 rows near the bottom
  print('Bottom curve verification:');
  for (int y = image.height - 40; y < image.height; y += 4) {
    int left = -1, right = -1;
    for (int x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a > 20) {
        if (left == -1) left = x;
        right = x;
      }
    }
    if (left != -1) {
      final w = right - left + 1;
      final mid = (left + right) / 2.0;
      print('Y=$y: left=$left, right=$right (width=$w, center=$mid)');
    } else {
      print('Y=$y: [TRANSPARENT]');
    }
  }
}
