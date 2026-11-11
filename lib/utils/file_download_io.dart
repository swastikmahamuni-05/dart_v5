import 'dart:io';
import 'dart:convert';

void saveFileToDisk({
  required String content,
  required String fileName,
  required String mimeType,
}) {
  try {
    Directory? targetDir;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          targetDir = downloads;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final downloads = Directory('$home/Downloads');
        if (downloads.existsSync()) {
          targetDir = downloads;
        }
      }
    } else if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (androidDownloads.existsSync()) {
        targetDir = androidDownloads;
      }
    }

    targetDir ??= Directory.systemTemp;

    final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${targetDir.path}${Platform.pathSeparator}$sanitizedName');

    // Prepend UTF-8 BOM (\uFEFF) for CSV, TSV, and text files so spreadsheet apps
    // immediately recognize the UTF-8 encoding and split columns cleanly.
    final bool needsBom = (fileName.endsWith('.csv') || fileName.endsWith('.tsv') || fileName.endsWith('.txt')) &&
        !content.startsWith('\uFEFF');
    final String fileContent = needsBom ? '\uFEFF$content' : content;

    file.writeAsStringSync(fileContent, encoding: utf8);
    print('LEVELS: File saved to disk: ${file.path}');
  } catch (e) {
    print('LEVELS: Failed to save file to disk on IO: $e');
  }
}
