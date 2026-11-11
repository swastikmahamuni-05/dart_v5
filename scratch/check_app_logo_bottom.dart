import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_logo.png');
  final imgObj = img.decodeImage(file.readAsBytesSync())!;

  print('Inspecting app_logo.png around Y=830..845:');
  for (int y = 830; y <= 845; y += 2) {
    for (int x = 265; x <= 760; x += 30) {
      final p = imgObj.getPixel(x, y);
      print('($x, $y): rgb=(${p.r}, ${p.g}, ${p.b})');
    }
  }
}
