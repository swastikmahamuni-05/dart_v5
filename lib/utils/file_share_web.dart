// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'file_share_types.dart';

Future<FileShareResult> platformShareFile({
  required String content,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async {
  try {
    final navigator = html.window.navigator;
    final hasShare = js_util.hasProperty(navigator, 'share');

    if (!hasShare) {
      return FileShareResult.unsupported(
        'File sharing is not supported by this browser. The report has been prepared and can be downloaded instead.',
      );
    }

    // Prepend UTF-8 BOM for spreadsheet / text files
    final bool needsBom = (fileName.endsWith('.csv') || fileName.endsWith('.tsv') || fileName.endsWith('.txt')) &&
        !content.startsWith('\uFEFF');
    final String fileContent = needsBom ? '\uFEFF$content' : content;
    final bytes = utf8.encode(fileContent);

    final blob = html.Blob([bytes], '$mimeType;charset=utf-8');
    final file = html.File([blob], fileName, {'type': '$mimeType;charset=utf-8'});

    // Check if canShare supports files
    bool canShareFiles = false;
    if (js_util.hasProperty(navigator, 'canShare')) {
      try {
        final testShareData = js_util.jsify({
          'files': [file],
        });
        canShareFiles = js_util.callMethod(navigator, 'canShare', [testShareData]) == true;
      } catch (_) {
        canShareFiles = false;
      }
    }

    if (!canShareFiles) {
      return FileShareResult.unsupported(
        'This browser does not support sharing files directly. Please use Download Report to save the file locally.',
      );
    }

    final shareData = js_util.jsify({
      'files': [file],
      'title': title ?? fileName,
      if (text != null && text.isNotEmpty) 'text': text,
    });

    final sharePromise = js_util.callMethod(navigator, 'share', [shareData]);
    await js_util.promiseToFuture(sharePromise);

    return FileShareResult.success('Report shared successfully');
  } catch (e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('abort') || errStr.contains('cancel')) {
      return FileShareResult.canceled();
    }
    return FileShareResult.error(
      'Unable to share report: ${e.toString().replaceAll('Exception:', '').trim()}',
    );
  }
}
