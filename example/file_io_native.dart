/// Native implementation using dart:io for desktop and mobile.
library;

import 'dart:io';

Future<String> readStringFromFile(String path) => File(path).readAsString();

Future<void> writeStringToFile(String path, String content) =>
    File(path).writeAsString(content);

/// Not used on native — file_picker handles save dialogs.
void downloadFile(String filename, String content) =>
    throw UnsupportedError('downloadFile is web-only');
