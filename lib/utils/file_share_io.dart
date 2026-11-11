import 'dart:io';
import 'dart:convert';
import 'file_share_types.dart';

Future<FileShareResult> platformShareFile({
  required String content,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async {
  try {
    final sanitizedName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}${Platform.pathSeparator}$sanitizedName');

    final bool needsBom = (fileName.endsWith('.csv') || fileName.endsWith('.tsv') || fileName.endsWith('.txt')) &&
        !content.startsWith('\uFEFF');
    final String fileContent = needsBom ? '\uFEFF$content' : content;

    file.writeAsStringSync(fileContent, encoding: utf8);

    return FileShareResult.success(
      'Report successfully generated and staged at: ${file.path}',
      file.path,
    );
  } catch (e) {
    return FileShareResult.error('Failed to stage report for sharing: $e');
  }
}
