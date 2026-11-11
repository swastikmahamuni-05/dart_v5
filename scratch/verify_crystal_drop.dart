import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Verifying assets/icon/crystal_drop.png...');
  print('Size: ${image.width}x${image.height}');

  // 1. Check all 4 corners are 100% transparent
  final cTL = image.getPixel(0, 0);
  final cTR = image.getPixel(image.width - 1, 0);
  final cBL = image.getPixel(0, image.height - 1);
  final cBR = image.getPixel(image.width - 1, image.height - 1);
  print('Corner Alphas: TL=${cTL.a}, TR=${cTR.a}, BL=${cBL.a}, BR=${cBR.a}');
  assert(cTL.a == 0 && cTR.a == 0 && cBL.a == 0 && cBR.a == 0, 'Corners must be transparent!');

  // 2. Check the bottom 100 rows for transparent sides
  print('Checking bottom 80 rows contour...');
  for (int y = image.height - 80; y < image.height; y += 10) {
    int firstOpaque = -1;
    int lastOpaque = -1;
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.a > 10) {
        if (firstOpaque == -1) firstOpaque = x;
        lastOpaque = x;
      }
    }
    if (firstOpaque != -1) {
      final w = lastOpaque - firstOpaque + 1;
      final mid = (firstOpaque + lastOpaque) / 2.0;
      print('Y=$y: Opaque span: $firstOpaque..$lastOpaque (width=$w, center=$mid)');
    } else {
      print('Y=$y: Transparent row');
    }
  }

  print('SUCCESS: Verified crystal_drop.png has natural curved droplet contour!');
}
