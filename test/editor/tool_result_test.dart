
import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/math/bounds.dart';
import 'package:markdraw/src/core/math/point.dart';
import 'package:markdraw/src/core/scene/scene.dart';
import 'package:markdraw/src/editor/tool_result.dart';
import 'package:markdraw/src/editor/tool_type.dart';
import 'package:markdraw/src/rendering/viewport_state.dart';

void main() {
  group('ToolType', () {
    test('has all 10 values', () {
      expect(ToolType.values.length, 10);
      expect(ToolType.values, containsAll([
        ToolType.select,
        ToolType.rectangle,
        ToolType.ellipse,
        ToolType.diamond,
        ToolType.line,
        ToolType.arrow,
        ToolType.freedraw,
        ToolType.text,
        ToolType.hand,
        ToolType.frame,
      ]));
    });
  });

  group('ToolResult', () {
    final element = RectangleElement(
      id: const ElementId('r1'),
      x: 10,
      y: 20,
      width: 100,
      height: 50,
    );

    test('AddElementResult holds element', () {
      final result = AddElementResult(element);
      expect(result.element, element);
    });

    test('UpdateElementResult holds element', () {
      final result = UpdateElementResult(element);
      expect(result.element, element);
    });

    test('RemoveElementResult holds element ID', () {
      final result = RemoveElementResult(const ElementId('r1'));
      expect(result.id, const ElementId('r1'));
    });

    test('SetSelectionResult holds set of IDs', () {
      final ids = {const ElementId('a'), const ElementId('b')};
      final result = SetSelectionResult(ids);
      expect(result.selectedIds, ids);
    });

    test('SetSelectionResult with empty set', () {
      final result = SetSelectionResult({});
      expect(result.selectedIds, isEmpty);
    });

    test('UpdateViewportResult holds viewport', () {
      const viewport = ViewportState(offset: Offset(10, 20), zoom: 2.0);
      final result = UpdateViewportResult(viewport);
      expect(result.viewport, viewport);
    });

    test('CompoundResult holds list of results', () {
      final results = [
        AddElementResult(element),
        SetSelectionResult({element.id}),
        SwitchToolResult(ToolType.select),
      ];
      final compound = CompoundResult(results);
      expect(compound.results.length, 3);
      expect(compound.results[0], isA<AddElementResult>());
      expect(compound.results[1], isA<SetSelectionResult>());
      expect(compound.results[2], isA<SwitchToolResult>());
    });

    test('SwitchToolResult holds tool type', () {
      final result = SwitchToolResult(ToolType.select);
      expect(result.toolType, ToolType.select);
    });

    test('SetClipboardResult holds elements', () {
      final result = SetClipboardResult([element]);
      expect(result.elements, hasLength(1));
      expect(result.elements.first, element);
    });

    test('SetClipboardResult with empty list', () {
      final result = SetClipboardResult([]);
      expect(result.elements, isEmpty);
    });

    test('ToolResult is sealed — all subtypes covered in switch', () {
      final ToolResult result = AddElementResult(element);
      // This switch must compile — exhaustiveness check for sealed class
      final description = switch (result) {
        AddElementResult() => 'add',
        UpdateElementResult() => 'update',
        RemoveElementResult() => 'remove',
        SetSelectionResult() => 'select',
        UpdateViewportResult() => 'viewport',
        CompoundResult() => 'compound',
        SwitchToolResult() => 'switch',
        SetClipboardResult() => 'clipboard',
        AddFileResult() => 'addFile',
      };
      expect(description, 'add');
    });
  });

  group('ToolContext', () {
    test('holds scene, viewport, and selectedIds', () {
      final scene = Scene();
      const viewport = ViewportState();
      final selectedIds = <ElementId>{};
      final context = ToolContext(
        scene: scene,
        viewport: viewport,
        selectedIds: selectedIds,
      );
      expect(context.scene, scene);
      expect(context.viewport, viewport);
      expect(context.selectedIds, selectedIds);
    });

    test('clipboard defaults to empty list', () {
      final context = ToolContext(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
      );
      expect(context.clipboard, isEmpty);
    });

    test('clipboard holds provided elements', () {
      final elem = RectangleElement(
        id: const ElementId('r1'),
        x: 10,
        y: 20,
        width: 100,
        height: 50,
      );
      final context = ToolContext(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: {},
        clipboard: [elem],
      );
      expect(context.clipboard, hasLength(1));
    });

    test('selectedIds is an unmodifiable view', () {
      final selectedIds = {const ElementId('a')};
      final context = ToolContext(
        scene: Scene(),
        viewport: const ViewportState(),
        selectedIds: selectedIds,
      );
      // Modifying the original shouldn't affect the context
      selectedIds.add(const ElementId('b'));
      expect(context.selectedIds.length, 1);
    });
  });

  group('isSceneChangingResult', () {
    final element = RectangleElement(
      id: const ElementId('r1'),
      x: 10,
      y: 20,
      width: 100,
      height: 50,
    );

    test('true for AddElementResult', () {
      expect(isSceneChangingResult(AddElementResult(element)), isTrue);
    });

    test('true for UpdateElementResult', () {
      expect(isSceneChangingResult(UpdateElementResult(element)), isTrue);
    });

    test('true for RemoveElementResult', () {
      expect(
          isSceneChangingResult(RemoveElementResult(const ElementId('r1'))),
          isTrue);
    });

    test('false for non-scene-changing results', () {
      expect(isSceneChangingResult(SetSelectionResult({})), isFalse);
      expect(
          isSceneChangingResult(
              UpdateViewportResult(const ViewportState())),
          isFalse);
      expect(
          isSceneChangingResult(SwitchToolResult(ToolType.select)), isFalse);
      expect(isSceneChangingResult(SetClipboardResult([])), isFalse);
    });

    test('true for CompoundResult containing scene change', () {
      final compound = CompoundResult([
        SetSelectionResult({const ElementId('r1')}),
        AddElementResult(element),
      ]);
      expect(isSceneChangingResult(compound), isTrue);
    });

    test('false for CompoundResult with only non-scene results', () {
      final compound = CompoundResult([
        SetSelectionResult({const ElementId('r1')}),
        SwitchToolResult(ToolType.select),
      ]);
      expect(isSceneChangingResult(compound), isFalse);
    });

    test('false for null', () {
      expect(isSceneChangingResult(null), isFalse);
    });
  });

  group('ToolOverlay', () {
    test('creationBounds holds bounds during shape creation', () {
      final overlay = ToolOverlay(
        creationBounds: Bounds.fromLTWH(10, 20, 100, 50),
      );
      expect(overlay.creationBounds, isNotNull);
      expect(overlay.creationBounds!.left, 10);
      expect(overlay.creationPoints, isNull);
      expect(overlay.marqueeRect, isNull);
    });

    test('creationPoints holds points during line creation', () {
      const overlay = ToolOverlay(
        creationPoints: [Point(0, 0), Point(100, 100)],
      );
      expect(overlay.creationPoints, hasLength(2));
      expect(overlay.creationBounds, isNull);
    });

    test('marqueeRect holds rect during marquee selection', () {
      final overlay = ToolOverlay(
        marqueeRect: Bounds.fromLTWH(10, 10, 200, 150),
      );
      expect(overlay.marqueeRect, isNotNull);
      expect(overlay.marqueeRect!.right, 210);
    });

    test('all fields null by default', () {
      const overlay = ToolOverlay();
      expect(overlay.creationBounds, isNull);
      expect(overlay.creationPoints, isNull);
      expect(overlay.marqueeRect, isNull);
    });
  });
}
