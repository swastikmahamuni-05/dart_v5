import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final original = img.decodeImage(file.readAsBytesSync())!;

  print('Source app_logo.png size: ${original.width}x${original.height}');

  // In app_logo.png, the master droplet is located at:
  // X: 265..760, Y: 213..839
  // Width: 496, Height: 627
  // Center is at X: 512, Y: 526
  
  // Let's create an image for the droplet with transparent background.
  // Add padding: 24px around the droplet
  const padX = 20;
  const padY = 20;
  const minX = 265;
  const maxX = 760;
  const minY = 213;
  const maxY = 839;

  final cropW = (maxX - minX + 1) + padX * 2;
  final cropH = (maxY - minY + 1) + padY * 2;

  final cleanDrop = img.Image(width: cropW, height: cropH, numChannels: 4);
  // Initialize all pixels to transparent
  img.fill(cleanDrop, color: img.ColorRgba8(0, 0, 0, 0));

  // Extract droplet pixels from app_logo.png
  // The background in app_logo.png is pure white (255, 255, 255).
  // Droplet facet pixels have colorful saturation or darkness.
  // For pixels at the boundary, we calculate alpha based on distance from pure white to provide
  // smooth antialiased edges without any dark or white halos.

  for (int y = minY - padY; y <= maxY + padY; y++) {
    if (y < 0 || y >= original.height) continue;
    final destY = y - (minY - padY);

    for (int x = minX - padX; x <= maxX + padX; x++) {
      if (x < 0 || x >= original.width) continue;
      final destX = x - (minX - padX);

      final p = original.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      // Check distance from white (255, 255, 255)
      // Pure white is 0 distance.
      // Droplet pixels have substantial distance or saturation.
      final diffR = 255 - r;
      final diffG = 255 - g;
      final diffB = 255 - b;
      final maxDiff = [diffR, diffG, diffB].reduce((a, b) => a > b ? a : b);
      final avgDiff = (diffR + diffG + diffB) / 3.0;

      // Check if pixel is within the bounding geometry of the droplet
      // Below maxY (839), everything must be strictly transparent!
      // Above minY (213), everything must be strictly transparent!
      if (y < minY || y > maxY || x < minX || x > maxX) {
        cleanDrop.setPixelRgba(destX, destY, 0, 0, 0, 0);
        continue;
      }

      // Check if pixel is outside the curved contour:
      // At row y, if it's near white background:
      if (maxDiff < 8 && avgDiff < 5) {
        // Pure background white -> completely transparent
        cleanDrop.setPixelRgba(destX, destY, 0, 0, 0, 0);
      } else if (maxDiff < 28 && avgDiff < 18) {
        // Antialiased border pixel: smoothly ramp alpha from 0 to 255
        final t = (maxDiff / 28.0).clamp(0.0, 1.0);
        // Antialiased alpha curve
        final alpha = (t * t * 255).round().clamp(0, 255);
        // Un-multiply color against white background so it doesn't look washed out
        final cleanR = ((r - 255 * (1 - t)) / t).round().clamp(0, 255);
        final cleanG = ((g - 255 * (1 - t)) / t).round().clamp(0, 255);
        final cleanB = ((b - 255 * (1 - t)) / t).round().clamp(0, 255);
        cleanDrop.setPixelRgba(destX, destY, cleanR, cleanG, cleanB, alpha);
      } else {
        // Solid facet pixel
        cleanDrop.setPixelRgba(destX, destY, r, g, b, 255);
      }
    }
  }

  // Save cleanDrop as crystal_drop.png
  final outBytes = img.encodePng(cleanDrop);
  File('assets/icon/crystal_drop.png').writeAsBytesSync(outBytes);
  print('Saved assets/icon/crystal_drop.png: ${cleanDrop.width}x${cleanDrop.height}');
}
