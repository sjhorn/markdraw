/// Web implementation — dart:io is not available on web.
///
/// File read/write by path is not supported; the app uses
/// file_picker bytes instead. Save uses a blob download.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:convert';

Future<String> readStringFromFile(String path) =>
    throw UnsupportedError('File read by path not supported on web');

Future<void> writeStringToFile(String path, String content) =>
    throw UnsupportedError('File write by path not supported on web');

/// Triggers a browser file download with the given filename and content.
void downloadFile(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
