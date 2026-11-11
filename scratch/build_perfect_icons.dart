import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final cleanDropFile = File('scratch/clean_drop.png');
  if (!cleanDropFile.existsSync()) {
    print('clean_drop.png not found');
    return;
  }
  final dropImg = img.decodeImage(cleanDropFile.readAsBytesSync())!;

  print('Clean drop size: ${dropImg.width}x${dropImg.height}');

  // --------------------------------------------------------------------------
  // 1. Create Master Adaptive Foreground (1024x1024, Transparent)
  // --------------------------------------------------------------------------
  // With Android Adaptive Icon 16% inset:
  // Visible region width/height is (1 - 0.32) * 1024 = 696px.
  // We want the drop height to be ~540px inside the visible 696px mask.
  // Therefore, before 16% inset, drop height in 1024x1024 should be:
  // 540 / 0.68 ≈ 794px.
  const masterSize = 1024;
  const targetForegroundDropHeight = 790;
  final fgScale = targetForegroundDropHeight / dropImg.height;
  final fgWidth = (dropImg.width * fgScale).round();

  final fgResizedDrop = img.copyResize(
    dropImg,
    width: fgWidth,
    height: targetForegroundDropHeight,
    interpolation: img.Interpolation.cubic,
  );

  // Optical center adjustment for teardrop shape (+10px down)
  final fgDestX = (masterSize - fgWidth) ~/ 2;
  final fgDestY = ((masterSize - targetForegroundDropHeight) ~/ 2) + 12;

  final masterForeground = img.Image(width: masterSize, height: masterSize, numChannels: 4);
  img.compositeImage(masterForeground, fgResizedDrop, dstX: fgDestX, dstY: fgDestY);

  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(masterForeground));
  print('Generated master adaptive foreground: assets/icon/app_icon_foreground.png');

  // --------------------------------------------------------------------------
  // 2. Create Master Full Icon (1024x1024, Pure White Background)
  // --------------------------------------------------------------------------
  // For standalone icons (legacy Android launcher, iOS, app stores):
  // The drop should occupy ~62% of the icon (approx 635px height).
  const targetFullDropHeight = 640;
  final fullScale = targetFullDropHeight / dropImg.height;
  final fullWidth = (dropImg.width * fullScale).round();

  final fullResizedDrop = img.copyResize(
    dropImg,
    width: fullWidth,
    height: targetFullDropHeight,
    interpolation: img.Interpolation.cubic,
  );

  final fullDestX = (masterSize - fullWidth) ~/ 2;
  final fullDestY = ((masterSize - targetFullDropHeight) ~/ 2) + 8;

  final masterFull = img.Image(width: masterSize, height: masterSize, numChannels: 4);
  img.fill(masterFull, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(masterFull, fullResizedDrop, dstX: fullDestX, dstY: fullDestY);

  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(masterFull));
  File('assets/icon/app_logo.png').writeAsBytesSync(img.encodePng(masterFull));
  File('assets/icon/app_logo.jpg').writeAsBytesSync(img.encodeJpg(masterFull, quality: 95));
  print('Generated master full icons: assets/icon/app_icon.png, app_logo.png, app_logo.jpg');

  // --------------------------------------------------------------------------
  // 3. Generate Android Adaptive Foreground across all densities
  // --------------------------------------------------------------------------
  final foregroundDensities = {
    'drawable-mdpi': 108,
    'drawable-hdpi': 162,
    'drawable-xhdpi': 216,
    'drawable-xxhdpi': 324,
    'drawable-xxxhdpi': 432,
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };

  for (final entry in foregroundDensities.entries) {
    final dir = Directory('android/app/src/main/res/${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final resizedFg = img.copyResize(
      masterForeground,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final outFile = File('${dir.path}/ic_launcher_foreground.png');
    outFile.writeAsBytesSync(img.encodePng(resizedFg));
    print('Wrote ${outFile.path} (${entry.value}x${entry.value})');
  }

  // --------------------------------------------------------------------------
  // 4. Generate Legacy Square/Squircle Icons (ic_launcher.png)
  // --------------------------------------------------------------------------
  final legacyDensities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in legacyDensities.entries) {
    final dir = Directory('android/app/src/main/res/${entry.key}');
    final size = entry.value;

    final resized = img.copyResize(
      masterFull,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final outFile = File('${dir.path}/ic_launcher.png');
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Wrote ${outFile.path} (${size}x$size)');
  }

  // --------------------------------------------------------------------------
  // 5. Generate Legacy Round Icons (ic_launcher_round.png)
  // --------------------------------------------------------------------------
  for (final entry in legacyDensities.entries) {
    final dir = Directory('android/app/src/main/res/${entry.key}');
    final size = entry.value;

    final squareImg = img.copyResize(
      masterFull,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );

    // Apply circular mask
    final roundImg = img.Image(width: size, height: size, numChannels: 4);
    final center = size / 2.0;
    final r = (size / 2.0) - 0.5;

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center + 0.5;
        final dy = y - center + 0.5;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist <= r - 0.5) {
          roundImg.setPixel(x, y, squareImg.getPixel(x, y));
        } else if (dist <= r + 0.5) {
          final alphaFactor = (r + 0.5 - dist).clamp(0.0, 1.0);
          final p = squareImg.getPixel(x, y);
          roundImg.setPixelRgba(x, y, p.r, p.g, p.b, (255 * alphaFactor).round());
        }
      }
    }

    final outFile = File('${dir.path}/ic_launcher_round.png');
    outFile.writeAsBytesSync(img.encodePng(roundImg));
    print('Wrote ${outFile.path} (${size}x$size)');
  }

  // --------------------------------------------------------------------------
  // 6. Generate One UI Squircle Simulation for Verification
  // --------------------------------------------------------------------------
  final sim = img.Image(width: 400, height: 400, numChannels: 4);
  img.fill(sim, color: img.ColorRgba8(0, 0, 0, 0));

  final simFull = img.copyResize(masterFull, width: 400, height: 400, interpolation: img.Interpolation.cubic);
  for (int y = 0; y < 400; y++) {
    for (int x = 0; x < 400; x++) {
      final nx = ((x - 200) / 185.0).abs();
      final ny = ((y - 200) / 185.0).abs();
      final dist = pow(nx, 3.2) + pow(ny, 3.2);
      if (dist <= 1.0) {
        sim.setPixel(x, y, simFull.getPixel(x, y));
      }
    }
  }
  File('scratch/samsung_squircle_verification.png').writeAsBytesSync(img.encodePng(sim));
  print('Saved scratch/samsung_squircle_verification.png');
}
