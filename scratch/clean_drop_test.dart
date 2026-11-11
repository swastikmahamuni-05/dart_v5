import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final original = img.decodeImage(file.readAsBytesSync())!;

  // Crop the drop from app_logo.png
  // The drop is between X: 301..735, Y: 231..781
  // Let's create a clean 1024x1024 image with pure white background,
  // and center the crystal drop directly in the middle.

  // Let's extract the drop by copying pixels where saturation > threshold
  // Or let's see how clean crystal_drop.png is on white.
  final dropFile = File('assets/icon/crystal_drop.png');
  final dropImg = img.decodeImage(dropFile.readAsBytesSync())!;

  // If we place dropImg onto a transparent 1024x1024 canvas,
  // first let's clean any non-drop pixels (pure white or near-white background) to transparent.
  final cleanDrop = img.Image(width: dropImg.width, height: dropImg.height, numChannels: 4);

  for (int y = 0; y < dropImg.height; y++) {
    for (int x = 0; x < dropImg.width; x++) {
      final p = dropImg.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final a = p.a;

      // Distance from pure white
      final distFromWhite = 255 - ((r + g + b) / 3);
      final isWhite = r > 245 && g > 245 && b > 245;

      if (a < 10 || (isWhite && distFromWhite < 10)) {
        // Transparent
        cleanDrop.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (distFromWhite < 35 && (r > 230 && g > 230 && b > 230)) {
        // Soft edge fade into transparent
        final alphaFactor = (distFromWhite / 35.0).clamp(0.0, 1.0);
        cleanDrop.setPixelRgba(x, y, r, g, b, (a * alphaFactor).round());
      } else {
        cleanDrop.setPixelRgba(x, y, r, g, b, a);
      }
    }
  }

  // Save cleanDrop
  File('scratch/clean_drop.png').writeAsBytesSync(img.encodePng(cleanDrop));
  print('Saved scratch/clean_drop.png');
}
