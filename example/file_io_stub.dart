/// Web stub — dart:io is not available on web.
///
/// File read/write by path is not supported; the app uses
/// file_picker bytes instead.
library;

Future<String> readStringFromFile(String path) =>
    throw UnsupportedError('File read by path not supported on web');

Future<void> writeStringToFile(String path, String content) =>
    throw UnsupportedError('File write by path not supported on web');
