import 'dart:io';

void main() {
  final dir = Directory('android/app/src/main/res');
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final stat = entity.statSync();
      final age = DateTime.now().difference(stat.modified);
      if (age.inMinutes < 15) {
        print('${entity.path} (modified ${age.inSeconds}s ago, ${stat.size} bytes)');
      }
    }
  }
}
