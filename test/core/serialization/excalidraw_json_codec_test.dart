import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/roundness.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/serialization/document_section.dart';
import 'package:markdraw/src/core/serialization/excalidraw_json_codec.dart';

String _wrapElements(List<Map<String, dynamic>> elements) {
  return jsonEncode({
    'type': 'excalidraw',
    'version': 2,
    'source': 'https://excalidraw.com',
    'elements': elements,
    'appState': {},
    'files': {},
  });
}

Map<String, dynamic> _baseElement({
  required String id,
  required String type,
  double x = 0,
  double y = 0,
  double width = 100,
  double height = 50,
  double angle = 0,
  String strokeColor = '#000000',
  String backgroundColor = 'transparent',
  String fillStyle = 'solid',
  double strokeWidth = 2,
  String strokeStyle = 'solid',
  double roughness = 1,
  int opacity = 100,
  Map<String, dynamic>? roundness,
  int seed = 42,
  int version = 1,
  int versionNonce = 123,
  bool isDeleted = false,
  List<String>? groupIds,
  String? frameId,
  List<Map<String, dynamic>>? boundElements,
  int updated = 1000000,
  String? link,
  bool locked = false,
  String? index,
}) {
  return {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'angle': angle,
    'strokeColor': strokeColor,
    'backgroundColor': backgroundColor,
    'fillStyle': fillStyle,
    'strokeWidth': strokeWidth,
    'strokeStyle': strokeStyle,
    'roughness': roughness,
    'opacity': opacity,
    if (roundness != null) 'roundness': roundness,
    'seed': seed,
    'version': version,
    'versionNonce': versionNonce,
    'isDeleted': isDeleted,
    'groupIds': groupIds ?? [],
    if (frameId != null) 'frameId': frameId,
    'boundElements': boundElements,
    'updated': updated,
    if (link != null) 'link': link,
    'locked': locked,
    if (index != null) 'index': index,
  };
}

void main() {
  group('ExcalidrawJsonCodec.parse', () {
    group('document structure', () {
      test('parses minimal valid JSON', () {
        final json = _wrapElements([
          _baseElement(id: 'rect1', type: 'rectangle'),
          _baseElement(id: 'ell1', type: 'ellipse'),
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(2));
        expect(result.value.sections, hasLength(1));
        expect(result.value.sections.first, isA<SketchSection>());
        expect(result.value.aliases, isEmpty);
      });

      test('empty elements array produces empty document', () {
        final json = _wrapElements([]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, isEmpty);
        expect(result.value.sections, hasLength(1));
        expect(
          (result.value.sections.first as SketchSection).elements,
          isEmpty,
        );
      });

      test('invalid JSON produces warning and empty document', () {
        final result = ExcalidrawJsonCodec.parse('not json at all');
        expect(result.value.allElements, isEmpty);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings.first.message, contains('Invalid JSON'));
      });

      test('missing elements key produces warning', () {
        final json = jsonEncode({
          'type': 'excalidraw',
          'version': 2,
          'source': 'test',
        });
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, isEmpty);
        expect(result.hasWarnings, isTrue);
      });

      test('unknown element types are skipped with warning', () {
        final json = _wrapElements([
          _baseElement(id: 'rect1', type: 'rectangle'),
          _baseElement(id: 'img1', type: 'image'),
          _baseElement(id: 'frame1', type: 'frame'),
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        expect(result.warnings, hasLength(2));
        expect(
          result.warnings[0].message,
          contains('image'),
        );
        expect(
          result.warnings[1].message,
          contains('frame'),
        );
      });
    });

    group('rectangle', () {
      test('parses rectangle with all base properties', () {
        final json = _wrapElements([
          _baseElement(
            id: 'rect1',
            type: 'rectangle',
            x: 100,
            y: 200,
            width: 160,
            height: 80,
            angle: 0.5,
            strokeColor: '#ff0000',
            backgroundColor: '#00ff00',
            fillStyle: 'cross-hatch',
            strokeWidth: 4,
            strokeStyle: 'dashed',
            roughness: 2,
            opacity: 50,
            roundness: {'type': 3, 'value': 10.0},
            seed: 42,
            version: 3,
            versionNonce: 456,
            isDeleted: false,
            groupIds: ['g1', 'g2'],
            locked: true,
            updated: 999,
          ),
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<RectangleElement>());
        expect(el.id.value, 'rect1');
        expect(el.x, 100.0);
        expect(el.y, 200.0);
        expect(el.width, 160.0);
        expect(el.height, 80.0);
        expect(el.angle, 0.5);
        expect(el.strokeColor, '#ff0000');
        expect(el.backgroundColor, '#00ff00');
        expect(el.fillStyle, FillStyle.crossHatch);
        expect(el.strokeWidth, 4.0);
        expect(el.strokeStyle, StrokeStyle.dashed);
        expect(el.roughness, 2.0);
        expect(el.opacity, 0.5); // 50 / 100
        expect(el.roundness, isNotNull);
        expect(el.roundness!.type, RoundnessType.adaptive);
        expect(el.roundness!.value, 10.0);
        expect(el.seed, 42);
        expect(el.version, 3);
        expect(el.versionNonce, 456);
        expect(el.isDeleted, false);
        expect(el.groupIds, ['g1', 'g2']);
        expect(el.locked, true);
        expect(el.updated, 999);
      });

      test('opacity 100 converts to 1.0', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', opacity: 100),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.opacity, 1.0);
      });

      test('opacity 0 converts to 0.0', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', opacity: 0),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.opacity, 0.0);
      });

      test('roundness type 1 maps to adaptive', () {
        final json = _wrapElements([
          _baseElement(
            id: 'r1',
            type: 'rectangle',
            roundness: {'type': 1},
          ),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.roundness!.type, RoundnessType.adaptive);
      });

      test('roundness type 2 maps to proportional', () {
        final json = _wrapElements([
          _baseElement(
            id: 'r1',
            type: 'rectangle',
            roundness: {'type': 2},
          ),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.roundness!.type, RoundnessType.proportional);
      });

      test('roundness type 3 maps to adaptive', () {
        final json = _wrapElements([
          _baseElement(
            id: 'r1',
            type: 'rectangle',
            roundness: {'type': 3, 'value': 15.0},
          ),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.roundness!.type, RoundnessType.adaptive);
        expect(el.roundness!.value, 15.0);
      });

      test('null roundness stays null', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle'),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.roundness, isNull);
      });

      test('fillStyle hachure maps correctly', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', fillStyle: 'hachure'),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.fillStyle, FillStyle.hachure);
      });

      test('fillStyle zigzag maps correctly', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', fillStyle: 'zigzag'),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.fillStyle, FillStyle.zigzag);
      });

      test('strokeStyle dotted maps correctly', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', strokeStyle: 'dotted'),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.strokeStyle, StrokeStyle.dotted);
      });

      test('boundElements null converts to empty list', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle'),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.boundElements, isEmpty);
      });

      test('boundElements array preserved', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'r1', type: 'rectangle'),
            'boundElements': [
              {'id': 'arrow1', 'type': 'arrow'},
              {'id': 'text1', 'type': 'text'},
            ],
          },
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.boundElements, hasLength(2));
        expect(el.boundElements[0].id, 'arrow1');
        expect(el.boundElements[0].type, 'arrow');
        expect(el.boundElements[1].id, 'text1');
        expect(el.boundElements[1].type, 'text');
      });
    });

    group('ellipse', () {
      test('parses ellipse with fill and stroke', () {
        final json = _wrapElements([
          _baseElement(
            id: 'ell1',
            type: 'ellipse',
            x: 50,
            y: 60,
            width: 120,
            height: 80,
            backgroundColor: '#ffcc00',
            fillStyle: 'hachure',
            strokeStyle: 'dashed',
          ),
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<EllipseElement>());
        expect(el.id.value, 'ell1');
        expect(el.x, 50.0);
        expect(el.y, 60.0);
        expect(el.width, 120.0);
        expect(el.height, 80.0);
        expect(el.backgroundColor, '#ffcc00');
        expect(el.fillStyle, FillStyle.hachure);
        expect(el.strokeStyle, StrokeStyle.dashed);
      });
    });

    group('diamond', () {
      test('parses diamond with fill and stroke', () {
        final json = _wrapElements([
          _baseElement(
            id: 'dia1',
            type: 'diamond',
            x: 300,
            y: 150,
            width: 100,
            height: 100,
            strokeColor: '#0000ff',
            fillStyle: 'zigzag',
          ),
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<DiamondElement>());
        expect(el.id.value, 'dia1');
        expect(el.x, 300.0);
        expect(el.y, 150.0);
        expect(el.strokeColor, '#0000ff');
        expect(el.fillStyle, FillStyle.zigzag);
      });
    });

    group('deleted elements', () {
      test('deleted element is preserved with isDeleted true', () {
        final json = _wrapElements([
          _baseElement(id: 'r1', type: 'rectangle', isDeleted: true),
        ]);
        final el = ExcalidrawJsonCodec.parse(json).value.allElements.first;
        expect(el.isDeleted, isTrue);
      });
    });
  });
}
