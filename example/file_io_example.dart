// ignore_for_file: avoid_print
/// Example demonstrating DocumentService for file I/O.
///
/// This is a pure Dart console app (no Flutter UI) that shows how to wire
/// up DocumentService with real file read/write using dart:io.
///
/// Usage:
///   dart run example/file_io_example.dart
library;

import 'dart:io';

import 'package:markdraw/markdraw.dart';

void main() async {
  // Wire up DocumentService with dart:io file operations.
  final service = DocumentService(
    readFile: (path) => File(path).readAsString(),
    writeFile: (path, content) => File(path).writeAsString(content),
  );

  // Create a sample document with various element types.
  final doc = MarkdrawDocument(
    sections: [
      SketchSection([
        RectangleElement(
          id: const ElementId('auth'),
          x: 100,
          y: 200,
          width: 160,
          height: 80,
          backgroundColor: '#e3f2fd',
        ),
        EllipseElement(
          id: const ElementId('db'),
          x: 225,
          y: 400,
          width: 120,
          height: 80,
          backgroundColor: '#e8f5e9',
        ),
        TextElement(
          id: const ElementId('title'),
          x: 100,
          y: 50,
          width: 200,
          height: 30,
          text: 'Architecture Diagram',
          fontSize: 24,
        ),
      ]),
    ],
  );

  // Save as .markdraw
  final markdrawPath = '${Directory.systemTemp.path}/example.markdraw';
  await service.save(doc, markdrawPath);
  print('Saved .markdraw to $markdrawPath');
  print('Content:');
  print(await File(markdrawPath).readAsString());
  print('');

  // Save as .excalidraw (convert via format override)
  final excalidrawPath = '${Directory.systemTemp.path}/example.excalidraw';
  await service.save(doc, excalidrawPath);
  print('Saved .excalidraw to $excalidrawPath');
  print('');

  // Load the .markdraw file back
  final loaded = await service.load(markdrawPath);
  print('Loaded ${loaded.value.allElements.length} elements from .markdraw');
  for (final el in loaded.value.allElements) {
    print('  - ${el.type} (${el.id.value})');
  }
  if (loaded.hasWarnings) {
    print('Warnings:');
    for (final w in loaded.warnings) {
      print('  - ${w.message}');
    }
  }
  print('');

  // Convert .excalidraw → .markdraw
  final convertedPath = '${Directory.systemTemp.path}/converted.markdraw';
  final result = await service.convert(excalidrawPath, convertedPath);
  print('Converted .excalidraw → .markdraw');
  print('  Elements: ${result.value.allElements.length}');
  print('  Output: $convertedPath');

  // Verify round-trip
  final reloaded = await service.load(convertedPath);
  print('  Reloaded: ${reloaded.value.allElements.length} elements');
  print('');
  print('Format detection:');
  print('  .markdraw → ${DocumentService.detectFormat("file.markdraw")}');
  print('  .excalidraw → ${DocumentService.detectFormat("file.excalidraw")}');
  print('  .json → ${DocumentService.detectFormat("file.json")}');
}
