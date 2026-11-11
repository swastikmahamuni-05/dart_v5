import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final original = img.decodeImage(file.readAsBytesSync())!;

  print('Loaded app_logo.png: ${original.width}x${original.height}');

  // Bounding box of droplet in app_logo.png:
  // X: 265..760, Y: 213..839
  const minX = 264;
  const maxX = 761;
  const minY = 212;
  const maxY = 840;

  const pad = 12;
  final outW = (maxX - minX + 1) + pad * 2;
  final outH = (maxY - minY + 1) + pad * 2;

  // First create a boolean mask of solid facet pixels in the region
  final mask = List.generate(outH, (_) => List<bool>.filled(outW, false));

  for (int y = minY - pad; y <= maxY + pad; y++) {
    if (y < 0 || y >= original.height) continue;
    final destY = y - (minY - pad);

    for (int x = minX - pad; x <= maxX + pad; x++) {
      if (x < 0 || x >= original.width) continue;
      final destX = x - (minX - pad);

      if (y < minY || y > maxY || x < minX || x > maxX) continue;

      final p = original.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      final maxC = [r, g, b].reduce(max);
      final minC = [r, g, b].reduce(min);
      final avgC = (r + g + b) / 3.0;

      // Solid facet condition: vibrant hue or darkness
      final isFacet = (maxC - minC >= 12) || avgC <= 234;
      mask[destY][destX] = isFacet;
    }
  }

  // Remove any stray isolated pixels (noise filter)
  final cleanMask = List.generate(outH, (y) => List<bool>.from(mask[y]));
  for (int y = 1; y < outH - 1; y++) {
    for (int x = 1; x < outW - 1; x++) {
      if (mask[y][x]) {
        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (mask[y + dy][x + dx]) neighbors++;
          }
        }
        if (neighbors <= 2) cleanMask[y][x] = false;
      }
    }
  }

  final outImg = img.Image(width: outW, height: outH, numChannels: 4);
  img.fill(outImg, color: img.ColorRgba8(0, 0, 0, 0));

  for (int y = 0; y < outH; y++) {
    final origY = y + (minY - pad);
    if (origY < 0 || origY >= original.height) continue;

    for (int x = 0; x < outW; x++) {
      final origX = x + (minX - pad);
      if (origX < 0 || origX >= original.width) continue;

      final p = original.getPixel(origX, origY);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      if (cleanMask[y][x]) {
        // Interior solid facet
        outImg.setPixelRgba(x, y, r, g, b, 255);
      } else {
        // Check distance to nearest mask pixel within radius 1.8
        double minD = 999.0;
        int nearestR = r, nearestG = g, nearestB = b;
        for (int dy = -2; dy <= 2; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= outH) continue;
          for (int dx = -2; dx <= 2; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= outW) continue;
            if (cleanMask[ny][nx]) {
              final d = sqrt(dx * dx + dy * dy);
              if (d < minD) {
                minD = d;
                final np = original.getPixel(nx + (minX - pad), ny + (minY - pad));
                nearestR = np.r.toInt();
                nearestG = np.g.toInt();
                nearestB = np.b.toInt();
              }
            }
          }
        }

        if (minD <= 1.5) {
          // Antialiased border pixel
          final alpha = ((1.0 - (minD / 1.5)) * 255).round().clamp(0, 255);
          outImg.setPixelRgba(x, y, nearestR, nearestG, nearestB, alpha);
        } else {
          // Fully transparent
          outImg.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
  }

  File('assets/icon/crystal_drop.png').writeAsBytesSync(img.encodePng(outImg));
  print('Saved perfect assets/icon/crystal_drop.png: ${outImg.width}x${outImg.height}');
}
