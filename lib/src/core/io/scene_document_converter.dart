import '../scene/scene_exports.dart';
import '../serialization/serialization.dart';

/// Bridges [Scene] and [MarkdrawDocument] for file I/O integration.
class SceneDocumentConverter {
  SceneDocumentConverter._();

  /// Converts a [Scene] to a [MarkdrawDocument] containing its active elements.
  ///
  /// Optionally pass [settings] to include canvas-level settings such as
  /// the background color.
  static MarkdrawDocument sceneToDocument(
    Scene scene, {
    CanvasSettings? settings,
  }) {
    return MarkdrawDocument(
      sections: [SketchSection(scene.activeElements)],
      files: scene.files,
      settings: settings,
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
