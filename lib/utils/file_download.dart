import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart';

void downloadFile({
  required String content,
  required String fileName,
  required String mimeType,
}) {
  saveFileToDisk(content: content, fileName: fileName, mimeType: mimeType);
}
