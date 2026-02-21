/// Native implementation using dart:io for desktop and mobile.
library;

import 'dart:io';

Future<String> readStringFromFile(String path) => File(path).readAsString();

Future<void> writeStringToFile(String path, String content) =>
    File(path).writeAsString(content);
