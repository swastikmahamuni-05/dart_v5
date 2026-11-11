import 'file_share_types.dart';
export 'file_share_types.dart';

import 'file_share_stub.dart'
    if (dart.library.html) 'file_share_web.dart'
    if (dart.library.io) 'file_share_io.dart';

Future<FileShareResult> shareFile({
  required String content,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async {
  return platformShareFile(
    content: content,
    fileName: fileName,
    mimeType: mimeType,
    title: title,
    text: text,
  );
}
