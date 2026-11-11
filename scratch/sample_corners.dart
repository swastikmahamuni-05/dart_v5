import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Pixel values at bottom corners:');
  for (int y = 460; y < 560; y += 15) {
    for (int x in [0, 15, 30, 60, 100, 350, 400, 430, 454]) {
      final p = image.getPixel(x, y);
      print('($x, $y): rgba=(${p.r}, ${p.g}, ${p.b}, ${p.a})');
    }
  }
}
