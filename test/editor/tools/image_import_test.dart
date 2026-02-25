import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/markdraw.dart';

/// Computes a deterministic fileId from image bytes (SHA-1 first 8 hex chars).
String computeFileId(Uint8List bytes) {
  final digest = sha1.convert(bytes);
  return digest.toString().substring(0, 8);
}

/// Creates an import result for an image at the viewport center.
CompoundResult createImageImportResult({
  required Uint8List bytes,
  required String mimeType,
  required double naturalWidth,
  required double naturalHeight,
  required ViewportState viewport,
  required double screenWidth,
  required double screenHeight,
  double maxSize = 800,
}) {
  final fileId = computeFileId(bytes);
  final file = ImageFile(mimeType: mimeType, bytes: bytes);

  // Scale to fit within maxSize while preserving aspect ratio
  double width = naturalWidth;
  double height = naturalHeight;
  if (width > maxSize || height > maxSize) {
    final scale = maxSize / (width > height ? width : height);
    width *= scale;
    height *= scale;
  }

  // Place at viewport center
  final centerScene = viewport.screenToScene(
    Offset(screenWidth / 2, screenHeight / 2),
  );
  final x = centerScene.dx - width / 2;
  final y = centerScene.dy - height / 2;

  final element = ImageElement(
    id: ElementId.generate(),
    x: x,
    y: y,
    width: width,
    height: height,
    fileId: fileId,
    mimeType: mimeType,
  );

  return CompoundResult([
    AddFileResult(fileId: fileId, file: file),
    AddElementResult(element),
    SetSelectionResult({element.id}),
  ]);
}

void main() {
  group('AddFileResult', () {
    test('holds file data', () {
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final result = AddFileResult(fileId: 'abc12345', file: file);
      expect(result.fileId, 'abc12345');
      expect(result.file, file);
    });

    test('isSceneChangingResult returns true for AddFileResult', () {
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final result = AddFileResult(fileId: 'abc12345', file: file);
      expect(isSceneChangingResult(result), isTrue);
    });
  });

  group('EditorState - AddFileResult', () {
    test('applyResult adds file to scene', () {
      final state = EditorState(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.select,
      );
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final result = AddFileResult(fileId: 'abc12345', file: file);
      final newState = state.applyResult(result);
      expect(newState.scene.files['abc12345'], file);
    });

    test('applyResult handles compound with AddFileResult', () {
      final state = EditorState(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        activeToolType: ToolType.select,
      );
      final file = ImageFile(
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final element = ImageElement(
        id: const ElementId('img1'),
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        fileId: 'abc12345',
      );
      final result = CompoundResult([
        AddFileResult(fileId: 'abc12345', file: file),
        AddElementResult(element),
        SetSelectionResult({element.id}),
      ]);
      final newState = state.applyResult(result);
      expect(newState.scene.files['abc12345'], file);
      expect(newState.scene.activeElements.length, 1);
      expect(newState.selectedIds, contains(element.id));
    });
  });

  group('fileId generation', () {
    test('deterministic from bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final id1 = computeFileId(bytes);
      final id2 = computeFileId(bytes);
      expect(id1, id2);
      expect(id1.length, 8);
    });

    test('different bytes produce different ids', () {
      final id1 = computeFileId(Uint8List.fromList([1, 2, 3]));
      final id2 = computeFileId(Uint8List.fromList([4, 5, 6]));
      expect(id1, isNot(equals(id2)));
    });
  });

  group('createImageImportResult', () {
    test('creates correct dimensions', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = createImageImportResult(
        bytes: bytes,
        mimeType: 'image/png',
        naturalWidth: 400,
        naturalHeight: 300,
        viewport: const ViewportState(),
        screenWidth: 800,
        screenHeight: 600,
      );

      expect(result.results.length, 3);
      final addFile = result.results[0] as AddFileResult;
      final addElement = result.results[1] as AddElementResult;
      final setSelection = result.results[2] as SetSelectionResult;

      expect(addFile.file.mimeType, 'image/png');
      expect(addElement.element, isA<ImageElement>());
      final img = addElement.element as ImageElement;
      expect(img.width, 400);
      expect(img.height, 300);
      expect(setSelection.selectedIds, contains(img.id));
    });

    test('preserves aspect ratio when scaling down', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = createImageImportResult(
        bytes: bytes,
        mimeType: 'image/png',
        naturalWidth: 1600,
        naturalHeight: 1200,
        viewport: const ViewportState(),
        screenWidth: 800,
        screenHeight: 600,
        maxSize: 800,
      );

      final addElement = result.results[1] as AddElementResult;
      final img = addElement.element as ImageElement;
      expect(img.width, 800);
      expect(img.height, 600);
      // Aspect ratio maintained: 1600/1200 = 800/600
      expect(img.width / img.height, closeTo(1600 / 1200, 0.01));
    });

    test('does not scale up small images', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = createImageImportResult(
        bytes: bytes,
        mimeType: 'image/png',
        naturalWidth: 200,
        naturalHeight: 150,
        viewport: const ViewportState(),
        screenWidth: 800,
        screenHeight: 600,
      );

      final addElement = result.results[1] as AddElementResult;
      final img = addElement.element as ImageElement;
      expect(img.width, 200);
      expect(img.height, 150);
    });

    test('places image at viewport center', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = createImageImportResult(
        bytes: bytes,
        mimeType: 'image/png',
        naturalWidth: 100,
        naturalHeight: 100,
        viewport: const ViewportState(),
        screenWidth: 800,
        screenHeight: 600,
      );

      final addElement = result.results[1] as AddElementResult;
      final img = addElement.element as ImageElement;
      // Viewport center in scene coords = (400, 300) at zoom 1.0
      // Image placed so center is at viewport center
      expect(img.x, closeTo(350, 1));
      expect(img.y, closeTo(250, 1));
    });
  });
}
