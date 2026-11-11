import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/crystal_drop.png');
  final image = img.decodeImage(file.readAsBytesSync())!;

  print('Analyzing crystal_drop.png contour...');
  // Check the bottom 100 rows
  for (int y = image.height - 80; y < image.height; y += 10) {
    int firstColored = -1;
    int lastColored = -1;
    int firstOpaque = -1;
    int lastOpaque = -1;
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.a > 30) {
        if (firstOpaque == -1) firstOpaque = x;
        lastOpaque = x;
      }
      final isColored = !(p.r > 235 && p.g > 235 && p.b > 235) && p.a > 30;
      if (isColored) {
        if (firstColored == -1) firstColored = x;
        lastColored = x;
      }
    }
    print('Y=$y: Opaque: $firstOpaque..$lastOpaque (w=${lastOpaque - firstOpaque + 1}), Colored: $firstColored..$lastColored (w=${lastColored - firstColored + 1})');
  }
}
