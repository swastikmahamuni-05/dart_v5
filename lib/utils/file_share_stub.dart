import 'file_share_types.dart';

Future<FileShareResult> platformShareFile({
  required String content,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async {
  return FileShareResult.unsupported();
}
