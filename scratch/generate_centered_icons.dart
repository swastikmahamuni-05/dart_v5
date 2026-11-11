import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final cleanDropFile = File('scratch/clean_drop.png');
  final dropImg = img.decodeImage(cleanDropFile.readAsBytesSync())!;

  print('Original drop: ${dropImg.width}x${dropImg.height}');

  // Desired drop height in 1024x1024 canvas:
  // Android Adaptive icon safe zone is 66dp/108dp = 61.1% (~625px)
  // Let's make the drop height 590px so it has balanced breathing room.
  const targetCanvasSize = 1024;
  const targetHeight = 590;
  final scale = targetHeight / dropImg.height;
  final targetWidth = (dropImg.width * scale).round();

  final resizedDrop = img.copyResize(
    dropImg,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  print('Resized drop: ${resizedDrop.width}x${resizedDrop.height}');

  // Optical center adjustment:
  // A teardrop's center of mass is slightly lower than its bounding box center.
  // Shifting down by 10px makes it look optically centered rather than floating too high.
  final destX = (targetCanvasSize - targetWidth) ~/ 2;
  final destY = ((targetCanvasSize - targetHeight) ~/ 2) + 8;

  // 1. Generate Adaptive Icon Foreground (Transparent 1024x1024)
  final foreground = img.Image(
    width: targetCanvasSize,
    height: targetCanvasSize,
    numChannels: 4,
  );
  img.compositeImage(foreground, resizedDrop, dstX: destX, dstY: destY);
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(foreground));
  print('Saved assets/icon/app_icon_foreground.png');

  // 2. Generate Full Icon (White background 1024x1024)
  final fullIcon = img.Image(
    width: targetCanvasSize,
    height: targetCanvasSize,
    numChannels: 4,
  );
  img.fill(fullIcon, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(fullIcon, resizedDrop, dstX: destX, dstY: destY);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(fullIcon));
  File('assets/icon/app_logo.png').writeAsBytesSync(img.encodePng(fullIcon));
  File('assets/icon/app_logo.jpg').writeAsBytesSync(img.encodeJpg(fullIcon, quality: 95));
  print('Saved assets/icon/app_icon.png, app_logo.png, app_logo.jpg');

  // 3. Generate Samsung Squircle Preview to compare directly with user screenshot!
  // In Samsung One UI, squircle corner radius is ~22.5% of width.
  final squirclePreview = img.Image(
    width: 300,
    height: 300,
    numChannels: 4,
  );
  // Transparent background
  img.fill(squirclePreview, color: img.ColorRgba8(0, 0, 0, 0));

  final smallFull = img.copyResize(fullIcon, width: 300, height: 300, interpolation: img.Interpolation.cubic);

  // Apply squircle mask: superellipse (|x/a|^n + |y/b|^n <= 1) with n=3.2
  final radius = 150.0;
  for (int y = 0; y < 300; y++) {
    for (int x = 0; x < 300; x++) {
      final nx = ((x - 150) / 140.0).abs();
      final ny = ((y - 150) / 140.0).abs();
      final dist = pow(nx, 3.2) + pow(ny, 3.2);
      if (dist <= 1.0) {
        final p = smallFull.getPixel(x, y);
        squirclePreview.setPixel(x, y, p);
      }
    }
  }

  File('scratch/squircle_preview.png').writeAsBytesSync(img.encodePng(squirclePreview));
  print('Saved scratch/squircle_preview.png');
}
