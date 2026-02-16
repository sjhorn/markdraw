import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/ellipse_element.dart';
import 'package:markdraw/src/core/elements/fill_style.dart';
import 'package:markdraw/src/core/elements/freedraw_element.dart';
import 'package:markdraw/src/core/elements/line_element.dart';
import 'package:markdraw/src/core/elements/rectangle_element.dart';
import 'package:markdraw/src/core/elements/roundness.dart';
import 'package:markdraw/src/core/elements/stroke_style.dart';
import 'package:markdraw/src/core/elements/text_element.dart';
import 'package:markdraw/src/core/math/point.dart';
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

    group('text', () {
      test('parses text element with all properties', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text', x: 10, y: 20),
            'text': 'Hello World',
            'fontSize': 24,
            'fontFamily': 1,
            'textAlign': 'center',
            'containerId': 'rect1',
            'lineHeight': 1.5,
            'autoResize': false,
            'originalText': 'Hello World',
            'verticalAlign': 'middle',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<TextElement>());
        final text = el as TextElement;
        expect(text.text, 'Hello World');
        expect(text.fontSize, 24.0);
        expect(text.fontFamily, 'Virgil'); // fontFamily 1 → Virgil
        expect(text.textAlign, TextAlign.center);
        expect(text.containerId, 'rect1');
        expect(text.lineHeight, 1.5);
        expect(text.autoResize, false);
      });

      test('fontFamily number 2 maps to Helvetica', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
            'fontFamily': 2,
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as TextElement;
        expect(el.fontFamily, 'Helvetica');
      });

      test('fontFamily number 3 maps to Cascadia', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
            'fontFamily': 3,
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as TextElement;
        expect(el.fontFamily, 'Cascadia');
      });

      test('unknown fontFamily number uses default with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
            'fontFamily': 99,
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as TextElement;
        expect(el.fontFamily, 'Virgil');
        expect(result.hasWarnings, isTrue);
        expect(result.warnings.first.message, contains('font family'));
      });

      test('textAlign left is default', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as TextElement;
        expect(el.textAlign, TextAlign.left);
      });

      test('textAlign right maps correctly', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
            'textAlign': 'right',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as TextElement;
        expect(el.textAlign, TextAlign.right);
      });

      test('null containerId stays null', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'txt1', type: 'text'),
            'text': 'Hi',
            'containerId': null,
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as TextElement;
        expect(el.containerId, isNull);
      });
    });

    group('line', () {
      test('parses line element with points', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'line1', type: 'line'),
            'points': [
              [0, 0],
              [100, 50],
              [200, 0],
            ],
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<LineElement>());
        final line = el as LineElement;
        expect(line.points, hasLength(3));
        expect(line.points[0], const Point(0, 0));
        expect(line.points[1], const Point(100, 50));
        expect(line.points[2], const Point(200, 0));
      });

      test('parses line with arrowheads', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'line1', type: 'line'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'startArrowhead': 'arrow',
            'endArrowhead': 'triangle',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as LineElement;
        expect(el.startArrowhead, Arrowhead.arrow);
        expect(el.endArrowhead, Arrowhead.triangle);
      });

      test('null arrowheads stay null', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'line1', type: 'line'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'startArrowhead': null,
            'endArrowhead': null,
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as LineElement;
        expect(el.startArrowhead, isNull);
        expect(el.endArrowhead, isNull);
      });

      test('empty points list handled', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'line1', type: 'line'),
            'points': <List<num>>[],
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as LineElement;
        expect(el.points, isEmpty);
      });
    });

    group('arrow', () {
      test('parses arrow element with points and bindings', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'arr1', type: 'arrow'),
            'points': [
              [0, 0],
              [150, 75],
            ],
            'startArrowhead': null,
            'endArrowhead': 'arrow',
            'startBinding': {
              'elementId': 'rect1',
              'fixedPoint': [0.5, 1.0],
              'focus': 0,
              'gap': 1,
            },
            'endBinding': {
              'elementId': 'rect2',
              'fixedPoint': [0.5, 0.0],
              'focus': 0,
              'gap': 1,
            },
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<ArrowElement>());
        final arrow = el as ArrowElement;
        expect(arrow.points, hasLength(2));
        expect(arrow.points[0], const Point(0, 0));
        expect(arrow.points[1], const Point(150, 75));
        expect(arrow.startArrowhead, isNull);
        expect(arrow.endArrowhead, Arrowhead.arrow);
        expect(arrow.startBinding, isNotNull);
        expect(arrow.startBinding!.elementId, 'rect1');
        expect(arrow.startBinding!.fixedPoint, const Point(0.5, 1.0));
        expect(arrow.endBinding, isNotNull);
        expect(arrow.endBinding!.elementId, 'rect2');
        expect(arrow.endBinding!.fixedPoint, const Point(0.5, 0.0));
      });

      test('null bindings stay null', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'arr1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'startBinding': null,
            'endBinding': null,
          },
        ]);
        final arrow =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(arrow.startBinding, isNull);
        expect(arrow.endBinding, isNull);
      });

      test('elbowed arrow treated as normal arrow', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'arr1', type: 'arrow'),
            'points': [
              [0, 0],
              [50, 0],
              [50, 100],
              [100, 100],
            ],
            'elbowed': true,
          },
        ]);
        final arrow =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(arrow.points, hasLength(4));
      });
    });

    group('arrowhead mapping', () {
      test('arrow maps to arrow', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'arrow',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(el.endArrowhead, Arrowhead.arrow);
      });

      test('bar maps to bar', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'bar',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(el.endArrowhead, Arrowhead.bar);
      });

      test('dot maps to dot', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'dot',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(el.endArrowhead, Arrowhead.dot);
      });

      test('triangle maps to triangle', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'triangle',
          },
        ]);
        final el =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as ArrowElement;
        expect(el.endArrowhead, Arrowhead.triangle);
      });

      test('circle maps to dot with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'circle',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.dot);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings.first.message, contains('circle'));
      });

      test('circle_outline maps to dot with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'circle_outline',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.dot);
      });

      test('triangle_outline maps to triangle with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'triangle_outline',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.triangle);
      });

      test('diamond maps to triangle with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'diamond',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.triangle);
        expect(
          result.warnings.first.message,
          contains('diamond'),
        );
      });

      test('diamond_outline maps to triangle with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'diamond_outline',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.triangle);
      });

      test('crowfoot_one maps to arrow with warning', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'a1', type: 'arrow'),
            'points': [
              [0, 0],
              [100, 0],
            ],
            'endArrowhead': 'crowfoot_one',
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        final el = result.value.allElements.first as ArrowElement;
        expect(el.endArrowhead, Arrowhead.arrow);
        expect(
          result.warnings.first.message,
          contains('crowfoot_one'),
        );
      });
    });

    group('freedraw', () {
      test('parses freedraw element with points and pressures', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'fd1', type: 'freedraw'),
            'points': [
              [0, 0],
              [10, 5],
              [20, 3],
            ],
            'pressures': [0.5, 0.7, 0.3],
            'simulatePressure': false,
          },
        ]);
        final result = ExcalidrawJsonCodec.parse(json);
        expect(result.value.allElements, hasLength(1));
        final el = result.value.allElements.first;
        expect(el, isA<FreedrawElement>());
        final fd = el as FreedrawElement;
        expect(fd.points, hasLength(3));
        expect(fd.points[0], const Point(0, 0));
        expect(fd.points[1], const Point(10, 5));
        expect(fd.points[2], const Point(20, 3));
        expect(fd.pressures, [0.5, 0.7, 0.3]);
        expect(fd.simulatePressure, false);
      });

      test('simulatePressure true with empty pressures', () {
        final json = _wrapElements([
          {
            ..._baseElement(id: 'fd1', type: 'freedraw'),
            'points': [
              [0, 0],
              [10, 5],
            ],
            'pressures': <double>[],
            'simulatePressure': true,
          },
        ]);
        final fd =
            ExcalidrawJsonCodec.parse(json).value.allElements.first
                as FreedrawElement;
        expect(fd.simulatePressure, true);
        expect(fd.pressures, isEmpty);
      });
    });
  });
}
