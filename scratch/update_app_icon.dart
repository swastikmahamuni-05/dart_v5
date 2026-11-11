import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final dropFile = File('assets/icon/crystal_drop.png');
  final dropImg = img.decodeImage(dropFile.readAsBytesSync())!;

  // Generate 1024x1024 app_icon.png with pure white background and the clean drop centered
  const iconSize = 1024;
  final appIcon = img.Image(width: iconSize, height: iconSize, numChannels: 4);
  img.fill(appIcon, color: img.ColorRgba8(255, 255, 255, 255));

  // The drop should occupy ~64% of the icon height (approx 650px)
  const targetH = 650;
  final scale = targetH / dropImg.height;
  final targetW = (dropImg.width * scale).round();

  final resizedDrop = img.copyResize(dropImg, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
  final dstX = (iconSize - targetW) ~/ 2;
  final dstY = (iconSize - targetH) ~/ 2;

  img.compositeImage(appIcon, resizedDrop, dstX: dstX, dstY: dstY);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(appIcon));
  print('Updated assets/icon/app_icon.png');
}
