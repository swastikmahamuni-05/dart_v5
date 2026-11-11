// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

void saveFileToDisk({
  required String content,
  required String fileName,
  required String mimeType,
}) {
  // Prepend UTF-8 BOM (\uFEFF) for CSV, TSV, and text files so Microsoft Excel & Windows apps
  // immediately recognize the UTF-8 encoding and display all columns and characters cleanly.
  final bool needsBom = (fileName.endsWith('.csv') || fileName.endsWith('.tsv') || fileName.endsWith('.txt')) &&
      !content.startsWith('\uFEFF');
  final String fileContent = needsBom ? '\uFEFF$content' : content;
  final bytes = utf8.encode(fileContent);

  final blob = html.Blob([bytes], '$mimeType;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();

  // Crucial: Delay revocation by 15 seconds so Chromium/browser download manager
  // has ample time to stream the Blob to disk before the object URL is invalidated.
  // Immediate synchronous revocation causes download aborts or corrupt 0-byte files.
  Future.delayed(const Duration(seconds: 15), () {
    try {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  });
}
