import '../scene/scene.dart';
import '../serialization/document_section.dart';
import '../serialization/markdraw_document.dart';

/// Bridges [Scene] and [MarkdrawDocument] for file I/O integration.
class SceneDocumentConverter {
  SceneDocumentConverter._();

  /// Converts a [Scene] to a [MarkdrawDocument] containing its active elements.
  static MarkdrawDocument sceneToDocument(Scene scene) {
    return MarkdrawDocument(
      sections: [SketchSection(scene.activeElements)],
      files: scene.files,
    );
  }

  /// Converts a [MarkdrawDocument] to a [Scene] containing all its elements.
  static Scene documentToScene(MarkdrawDocument doc) {
    var scene = Scene();
    for (final element in doc.allElements) {
      scene = scene.addElement(element);
    }
    for (final entry in doc.files.entries) {
      scene = scene.addFile(entry.key, entry.value);
    }
    return scene;
  }
}
