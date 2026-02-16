import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/arrow_element.dart';
import 'package:markdraw/src/core/elements/diamond_element.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
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
import 'package:markdraw/src/core/serialization/markdraw_document.dart';

String _wrapElements(List<Map<String, dynamic>> elements) {
  return jsonEncode({
    'type': 'excalidraw',
    'version': 2,
    'source': 'https://excalidraw.com',
    'elements': elements,
    'appState': <String, dynamic>{},
    'files': <String, dynamic>{},
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
    'roundness': ?roundness,
    'seed': seed,
    'version': version,
    'versionNonce': versionNonce,
    'isDeleted': isDeleted,
    'groupIds': groupIds ?? [],
    'frameId': ?frameId,
    'boundElements': boundElements,
    'updated': updated,
    'link': ?link,
    'locked': locked,
    'index': ?index,
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

  group('ExcalidrawJsonCodec.serialize', () {
    test('empty document produces valid JSON structure', () {
      final doc = MarkdrawDocument(sections: [SketchSection(const [])]);
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['type'], 'excalidraw');
      expect(decoded['version'], 2);
      expect(decoded['source'], 'markdraw');
      expect(decoded['elements'], isEmpty);
      expect(decoded['appState'], isA<Map<String, dynamic>>());
      expect(decoded['files'], isA<Map<String, dynamic>>());
    });

    test('rectangle export with all properties', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('rect1'),
              x: 100,
              y: 200,
              width: 160,
              height: 80,
              angle: 0.5,
              strokeColor: '#ff0000',
              backgroundColor: '#00ff00',
              fillStyle: FillStyle.crossHatch,
              strokeWidth: 4,
              strokeStyle: StrokeStyle.dashed,
              roughness: 2,
              opacity: 0.5,
              roundness: const Roundness.adaptive(value: 10),
              seed: 42,
              version: 3,
              versionNonce: 456,
              isDeleted: false,
              groupIds: const ['g1', 'g2'],
              locked: true,
              updated: 999,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final elements = decoded['elements'] as List;
      expect(elements, hasLength(1));
      final el = elements[0] as Map<String, dynamic>;
      expect(el['id'], 'rect1');
      expect(el['type'], 'rectangle');
      expect(el['x'], 100.0);
      expect(el['y'], 200.0);
      expect(el['width'], 160.0);
      expect(el['height'], 80.0);
      expect(el['angle'], 0.5);
      expect(el['strokeColor'], '#ff0000');
      expect(el['backgroundColor'], '#00ff00');
      expect(el['fillStyle'], 'cross-hatch');
      expect(el['strokeWidth'], 4.0);
      expect(el['strokeStyle'], 'dashed');
      expect(el['roughness'], 2.0);
      expect(el['opacity'], 50); // 0.5 × 100
      expect(el['roundness']['type'], 3);
      expect(el['roundness']['value'], 10.0);
      expect(el['seed'], 42);
      expect(el['version'], 3);
      expect(el['versionNonce'], 456);
      expect(el['isDeleted'], false);
      expect(el['groupIds'], ['g1', 'g2']);
      expect(el['locked'], true);
      expect(el['updated'], 999);
    });

    test('text export with fontFamily and verticalAlign', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            TextElement(
              id: const ElementId('txt1'),
              x: 10,
              y: 20,
              width: 200,
              height: 30,
              text: 'Hello World',
              fontSize: 24,
              fontFamily: 'Helvetica',
              textAlign: TextAlign.center,
              containerId: 'rect1',
              lineHeight: 1.5,
              autoResize: false,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['type'], 'text');
      expect(el['text'], 'Hello World');
      expect(el['fontSize'], 24.0);
      expect(el['fontFamily'], 2); // Helvetica → 2
      expect(el['textAlign'], 'center');
      expect(el['containerId'], 'rect1');
      expect(el['lineHeight'], 1.5);
      expect(el['autoResize'], false);
      expect(el['originalText'], 'Hello World');
      expect(el['verticalAlign'], 'top');
    });

    test('line export with points and arrowheads', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            LineElement(
              id: const ElementId('line1'),
              x: 0,
              y: 0,
              width: 200,
              height: 50,
              points: const [Point(0, 0), Point(100, 50), Point(200, 0)],
              startArrowhead: Arrowhead.bar,
              endArrowhead: Arrowhead.triangle,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['type'], 'line');
      expect(el['points'], [
        [0.0, 0.0],
        [100.0, 50.0],
        [200.0, 0.0],
      ]);
      expect(el['startArrowhead'], 'bar');
      expect(el['endArrowhead'], 'triangle');
    });

    test('arrow export with bindings', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ArrowElement(
              id: const ElementId('arr1'),
              x: 0,
              y: 0,
              width: 150,
              height: 75,
              points: const [Point(0, 0), Point(150, 75)],
              endArrowhead: Arrowhead.arrow,
              startBinding: const PointBinding(
                elementId: 'rect1',
                fixedPoint: Point(0.5, 1.0),
              ),
              endBinding: const PointBinding(
                elementId: 'rect2',
                fixedPoint: Point(0.5, 0.0),
              ),
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['type'], 'arrow');
      expect(el['startBinding']['elementId'], 'rect1');
      expect(el['startBinding']['fixedPoint'], [0.5, 1.0]);
      expect(el['startBinding']['mode'], 'inside');
      expect(el['endBinding']['elementId'], 'rect2');
      expect(el['endBinding']['fixedPoint'], [0.5, 0.0]);
      expect(el['endBinding']['mode'], 'inside');
    });

    test('freedraw export with points and pressures', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            FreedrawElement(
              id: const ElementId('fd1'),
              x: 0,
              y: 0,
              width: 20,
              height: 5,
              points: const [Point(0, 0), Point(10, 5), Point(20, 3)],
              pressures: const [0.5, 0.7, 0.3],
              simulatePressure: false,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['type'], 'freedraw');
      expect(el['points'], [
        [0.0, 0.0],
        [10.0, 5.0],
        [20.0, 3.0],
      ]);
      expect(el['pressures'], [0.5, 0.7, 0.3]);
      expect(el['simulatePressure'], false);
    });

    test('boundElements empty list exports as null', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['boundElements'], isNull);
    });

    test('boundElements non-empty exports as array', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              boundElements: const [
                BoundElement(id: 'a1', type: 'arrow'),
              ],
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['boundElements'], [
        {'id': 'a1', 'type': 'arrow'},
      ]);
    });

    test('multiple sections flatten all elements', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
          SketchSection([
            EllipseElement(
              id: const ElementId('e1'),
              x: 200,
              y: 200,
              width: 80,
              height: 80,
              seed: 3,
              version: 1,
              versionNonce: 4,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final elements =
          (jsonDecode(jsonStr)['elements'] as List);
      expect(elements, hasLength(2));
    });

    test('roundness adaptive exports as type 3', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              roundness: const Roundness.adaptive(value: 10),
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['roundness']['type'], 3);
      expect(el['roundness']['value'], 10.0);
    });

    test('roundness proportional exports as type 2', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              roundness: const Roundness.proportional(value: 5),
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['roundness']['type'], 2);
      expect(el['roundness']['value'], 5.0);
    });

    test('null roundness exports as null', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            RectangleElement(
              id: const ElementId('r1'),
              x: 0,
              y: 0,
              width: 100,
              height: 50,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['roundness'], isNull);
    });

    test('null arrowhead bindings export as null', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            ArrowElement(
              id: const ElementId('arr1'),
              x: 0,
              y: 0,
              width: 100,
              height: 0,
              points: const [Point(0, 0), Point(100, 0)],
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final el =
          (jsonDecode(jsonStr)['elements'] as List)[0] as Map<String, dynamic>;
      expect(el['startBinding'], isNull);
      expect(el['endBinding'], isNull);
    });

    test('ellipse and diamond export correct types', () {
      final doc = MarkdrawDocument(
        sections: [
          SketchSection([
            EllipseElement(
              id: const ElementId('e1'),
              x: 0,
              y: 0,
              width: 100,
              height: 80,
              seed: 1,
              version: 1,
              versionNonce: 2,
              updated: 100,
            ),
            DiamondElement(
              id: const ElementId('d1'),
              x: 200,
              y: 200,
              width: 100,
              height: 100,
              seed: 3,
              version: 1,
              versionNonce: 4,
              updated: 100,
            ),
          ]),
        ],
      );
      final jsonStr = ExcalidrawJsonCodec.serialize(doc);
      final elements = jsonDecode(jsonStr)['elements'] as List;
      expect((elements[0] as Map)['type'], 'ellipse');
      expect((elements[1] as Map)['type'], 'diamond');
    });
  });

  group('round-trip', () {
    test('rectangle round-trips through JSON', () {
      final json = _wrapElements([
        {
          ..._baseElement(
            id: 'r1',
            type: 'rectangle',
            x: 10,
            y: 20,
            width: 100,
            height: 50,
            opacity: 75,
            fillStyle: 'cross-hatch',
            strokeStyle: 'dotted',
          ),
          'roundness': {'type': 3, 'value': 12.0},
          'boundElements': [
            {'id': 'a1', 'type': 'arrow'},
          ],
        },
      ]);

      // Import → Export → Import
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      final el1 = doc1.allElements.first;
      final el2 = doc2.allElements.first;

      expect(el2.id.value, el1.id.value);
      expect(el2.x, el1.x);
      expect(el2.y, el1.y);
      expect(el2.width, el1.width);
      expect(el2.height, el1.height);
      expect(el2.opacity, el1.opacity);
      expect(el2.fillStyle, el1.fillStyle);
      expect(el2.strokeStyle, el1.strokeStyle);
      expect(el2.roundness, el1.roundness);
      expect(el2.boundElements.length, el1.boundElements.length);
      expect(el2.boundElements[0].id, el1.boundElements[0].id);
    });

    test('opacity 50 round-trips: 50 → 0.5 → 50', () {
      final json = _wrapElements([
        _baseElement(id: 'r1', type: 'rectangle', opacity: 50),
      ]);
      final doc = ExcalidrawJsonCodec.parse(json).value;
      expect(doc.allElements.first.opacity, 0.5);
      final exported = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(exported);
      expect((decoded['elements'] as List)[0]['opacity'], 50);
    });

    test('roundness round-trips: {type:3, value:10}', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'r1', type: 'rectangle'),
          'roundness': {'type': 3, 'value': 10.0},
        },
      ]);
      final doc = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc);
      final decoded = jsonDecode(exported);
      final r = (decoded['elements'] as List)[0]['roundness'];
      expect(r['type'], 3);
      expect(r['value'], 10.0);
    });

    test('text element round-trips through JSON', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'txt1', type: 'text'),
          'text': 'Round trip test',
          'fontSize': 18,
          'fontFamily': 2,
          'textAlign': 'right',
          'containerId': 'r1',
          'lineHeight': 1.3,
          'autoResize': false,
        },
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      final t1 = doc1.allElements.first as TextElement;
      final t2 = doc2.allElements.first as TextElement;
      expect(t2.text, t1.text);
      expect(t2.fontSize, t1.fontSize);
      expect(t2.fontFamily, t1.fontFamily);
      expect(t2.textAlign, t1.textAlign);
      expect(t2.containerId, t1.containerId);
      expect(t2.lineHeight, t1.lineHeight);
      expect(t2.autoResize, t1.autoResize);
    });

    test('line element round-trips through JSON', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'l1', type: 'line'),
          'points': [
            [0, 0],
            [50, 25],
            [100, 0],
          ],
          'startArrowhead': 'bar',
          'endArrowhead': 'dot',
        },
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      final l1 = doc1.allElements.first as LineElement;
      final l2 = doc2.allElements.first as LineElement;
      expect(l2.points.length, l1.points.length);
      for (var i = 0; i < l1.points.length; i++) {
        expect(l2.points[i], l1.points[i]);
      }
      expect(l2.startArrowhead, l1.startArrowhead);
      expect(l2.endArrowhead, l1.endArrowhead);
    });

    test('arrow element with bindings round-trips', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'a1', type: 'arrow'),
          'points': [
            [0, 0],
            [100, 50],
          ],
          'startArrowhead': null,
          'endArrowhead': 'arrow',
          'startBinding': {
            'elementId': 'r1',
            'fixedPoint': [0.5, 1.0],
            'focus': 0,
            'gap': 1,
          },
          'endBinding': {
            'elementId': 'r2',
            'fixedPoint': [0.5, 0.0],
            'focus': 0,
            'gap': 1,
          },
        },
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      final a1 = doc1.allElements.first as ArrowElement;
      final a2 = doc2.allElements.first as ArrowElement;
      expect(a2.startBinding!.elementId, a1.startBinding!.elementId);
      expect(a2.startBinding!.fixedPoint, a1.startBinding!.fixedPoint);
      expect(a2.endBinding!.elementId, a1.endBinding!.elementId);
      expect(a2.endBinding!.fixedPoint, a1.endBinding!.fixedPoint);
      expect(a2.endArrowhead, a1.endArrowhead);
    });

    test('freedraw round-trips through JSON', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'fd1', type: 'freedraw'),
          'points': [
            [0, 0],
            [5, 3],
            [10, 1],
          ],
          'pressures': [0.4, 0.8, 0.2],
          'simulatePressure': false,
        },
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      final f1 = doc1.allElements.first as FreedrawElement;
      final f2 = doc2.allElements.first as FreedrawElement;
      expect(f2.points.length, f1.points.length);
      for (var i = 0; i < f1.points.length; i++) {
        expect(f2.points[i], f1.points[i]);
      }
      expect(f2.pressures, f1.pressures);
      expect(f2.simulatePressure, f1.simulatePressure);
    });

    test('ellipse and diamond round-trip', () {
      final json = _wrapElements([
        _baseElement(
          id: 'e1',
          type: 'ellipse',
          fillStyle: 'hachure',
          opacity: 80,
        ),
        _baseElement(
          id: 'd1',
          type: 'diamond',
          fillStyle: 'zigzag',
          opacity: 60,
        ),
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      expect(doc2.allElements, hasLength(2));
      expect(doc2.allElements[0], isA<EllipseElement>());
      expect(doc2.allElements[0].fillStyle, FillStyle.hachure);
      expect(doc2.allElements[0].opacity, closeTo(0.8, 0.01));
      expect(doc2.allElements[1], isA<DiamondElement>());
      expect(doc2.allElements[1].fillStyle, FillStyle.zigzag);
      expect(doc2.allElements[1].opacity, closeTo(0.6, 0.01));
    });

    test('deleted elements preserved in round-trip', () {
      final json = _wrapElements([
        _baseElement(id: 'r1', type: 'rectangle', isDeleted: true),
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;
      expect(doc2.allElements.first.isDeleted, isTrue);
    });

    test('groupIds preserved in round-trip', () {
      final json = _wrapElements([
        _baseElement(
          id: 'r1',
          type: 'rectangle',
          groupIds: ['g1', 'g2', 'g3'],
        ),
      ]);
      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;
      expect(doc2.allElements.first.groupIds, ['g1', 'g2', 'g3']);
    });

    test('default values for missing optional fields', () {
      // Minimal element with just required fields
      final json = jsonEncode({
        'type': 'excalidraw',
        'version': 2,
        'source': 'test',
        'elements': [
          {'id': 'r1', 'type': 'rectangle'},
        ],
        'appState': <String, dynamic>{},
        'files': <String, dynamic>{},
      });
      final result = ExcalidrawJsonCodec.parse(json);
      final el = result.value.allElements.first;
      expect(el.x, 0.0);
      expect(el.y, 0.0);
      expect(el.width, 0.0);
      expect(el.height, 0.0);
      expect(el.opacity, 1.0);
      expect(el.strokeColor, '#000000');
      expect(el.backgroundColor, 'transparent');
      expect(el.fillStyle, FillStyle.solid);
      expect(el.strokeStyle, StrokeStyle.solid);
      expect(el.roundness, isNull);
      expect(el.isDeleted, false);
      expect(el.locked, false);
    });

    test('large file: 100+ elements parse without error', () {
      final elements = List.generate(
        150,
        (i) => _baseElement(
          id: 'el$i',
          type: ['rectangle', 'ellipse', 'diamond'][i % 3],
          x: i * 10.0,
          y: i * 5.0,
        ),
      );
      final json = _wrapElements(elements);
      final result = ExcalidrawJsonCodec.parse(json);
      expect(result.value.allElements, hasLength(150));
      expect(result.warnings, isEmpty);
    });

    test('all 7 element types round-trip', () {
      final json = _wrapElements([
        _baseElement(id: 'r1', type: 'rectangle'),
        _baseElement(id: 'e1', type: 'ellipse'),
        _baseElement(id: 'd1', type: 'diamond'),
        {
          ..._baseElement(id: 't1', type: 'text'),
          'text': 'Hi',
          'fontFamily': 1,
        },
        {
          ..._baseElement(id: 'l1', type: 'line'),
          'points': [
            [0, 0],
            [100, 0],
          ],
        },
        {
          ..._baseElement(id: 'a1', type: 'arrow'),
          'points': [
            [0, 0],
            [100, 0],
          ],
          'endArrowhead': 'arrow',
        },
        {
          ..._baseElement(id: 'f1', type: 'freedraw'),
          'points': [
            [0, 0],
            [10, 5],
          ],
          'pressures': [0.5, 0.5],
          'simulatePressure': false,
        },
      ]);

      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      expect(doc1.allElements, hasLength(7));

      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;
      expect(doc2.allElements, hasLength(7));

      expect(doc2.allElements[0], isA<RectangleElement>());
      expect(doc2.allElements[1], isA<EllipseElement>());
      expect(doc2.allElements[2], isA<DiamondElement>());
      expect(doc2.allElements[3], isA<TextElement>());
      expect(doc2.allElements[4], isA<LineElement>());
      expect(doc2.allElements[5], isA<ArrowElement>());
      expect(doc2.allElements[6], isA<FreedrawElement>());
    });

    test('boundElements round-trip', () {
      final json = _wrapElements([
        {
          ..._baseElement(id: 'r1', type: 'rectangle'),
          'boundElements': [
            {'id': 'a1', 'type': 'arrow'},
            {'id': 't1', 'type': 'text'},
          ],
        },
      ]);

      final doc1 = ExcalidrawJsonCodec.parse(json).value;
      final exported = ExcalidrawJsonCodec.serialize(doc1);
      final doc2 = ExcalidrawJsonCodec.parse(exported).value;

      expect(doc2.allElements.first.boundElements, hasLength(2));
      expect(doc2.allElements.first.boundElements[0].id, 'a1');
      expect(doc2.allElements.first.boundElements[0].type, 'arrow');
      expect(doc2.allElements.first.boundElements[1].id, 't1');
      expect(doc2.allElements.first.boundElements[1].type, 'text');
    });
  });
}
