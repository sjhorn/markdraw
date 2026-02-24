import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/element.dart';
import 'package:markdraw/src/core/elements/element_id.dart';
import 'package:markdraw/src/core/groups/group_utils.dart';
import 'package:markdraw/src/core/scene/scene.dart';

Element _rect({
  required String id,
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 100,
  List<String> groupIds = const [],
}) =>
    Element(
      id: ElementId(id),
      type: 'rectangle',
      x: x,
      y: y,
      width: w,
      height: h,
      groupIds: groupIds,
    );

Element _ellipse({
  required String id,
  double x = 0,
  double y = 0,
  List<String> groupIds = const [],
}) =>
    Element(
      id: ElementId(id),
      type: 'ellipse',
      x: x,
      y: y,
      width: 100,
      height: 100,
      groupIds: groupIds,
    );

void main() {
  group('outermostGroupId', () {
    test('returns null for ungrouped element', () {
      final e = _rect(id: 'r1');
      expect(GroupUtils.outermostGroupId(e), isNull);
    });

    test('returns last groupId for single group', () {
      final e = _rect(id: 'r1', groupIds: ['g1']);
      expect(GroupUtils.outermostGroupId(e), 'g1');
    });

    test('returns last groupId for nested groups', () {
      final e = _rect(id: 'r1', groupIds: ['inner', 'outer']);
      expect(GroupUtils.outermostGroupId(e), 'outer');
    });
  });

  group('innermostGroupId', () {
    test('returns null for ungrouped element', () {
      final e = _rect(id: 'r1');
      expect(GroupUtils.innermostGroupId(e), isNull);
    });

    test('returns first groupId for single group', () {
      final e = _rect(id: 'r1', groupIds: ['g1']);
      expect(GroupUtils.innermostGroupId(e), 'g1');
    });

    test('returns first groupId for nested groups', () {
      final e = _rect(id: 'r1', groupIds: ['inner', 'outer']);
      expect(GroupUtils.innermostGroupId(e), 'inner');
    });
  });

  group('findGroupMembers', () {
    test('returns empty for no matches', () {
      final scene = Scene().addElement(_rect(id: 'r1'));
      expect(GroupUtils.findGroupMembers(scene, 'g1'), isEmpty);
    });

    test('finds all members of a group', () {
      final scene = Scene()
          .addElement(_rect(id: 'r1', groupIds: ['g1']))
          .addElement(_rect(id: 'r2', groupIds: ['g1']))
          .addElement(_rect(id: 'r3'));
      final members = GroupUtils.findGroupMembers(scene, 'g1');
      expect(members, hasLength(2));
      expect(members.map((e) => e.id.value), containsAll(['r1', 'r2']));
    });

    test('skips deleted elements', () {
      var scene = Scene()
          .addElement(_rect(id: 'r1', groupIds: ['g1']))
          .addElement(_rect(id: 'r2', groupIds: ['g1']));
      scene = scene.softDeleteElement(const ElementId('r2'));
      final members = GroupUtils.findGroupMembers(scene, 'g1');
      expect(members, hasLength(1));
      expect(members.first.id.value, 'r1');
    });

    test('handles nested groupIds — finds by inner group', () {
      final scene = Scene()
          .addElement(_rect(id: 'r1', groupIds: ['inner', 'outer']))
          .addElement(_rect(id: 'r2', groupIds: ['inner', 'outer']))
          .addElement(_rect(id: 'r3', groupIds: ['outer']));
      final members = GroupUtils.findGroupMembers(scene, 'inner');
      expect(members, hasLength(2));
    });
  });

  group('expandToGroup', () {
    test('adds all group members to id set', () {
      final scene = Scene()
          .addElement(_rect(id: 'r1', groupIds: ['g1']))
          .addElement(_rect(id: 'r2', groupIds: ['g1']))
          .addElement(_rect(id: 'r3'));
      final expanded = GroupUtils.expandToGroup(
        scene,
        {const ElementId('r1')},
        'g1',
      );
      expect(expanded, hasLength(2));
      expect(expanded, contains(const ElementId('r2')));
    });

    test('preserves existing ids not in group', () {
      final scene = Scene()
          .addElement(_rect(id: 'r1', groupIds: ['g1']))
          .addElement(_rect(id: 'r2'));
      final expanded = GroupUtils.expandToGroup(
        scene,
        {const ElementId('r1'), const ElementId('r2')},
        'g1',
      );
      expect(expanded, hasLength(2));
      expect(expanded, contains(const ElementId('r2')));
    });

    test('returns original set when group has no members', () {
      final scene = Scene().addElement(_rect(id: 'r1'));
      final ids = {const ElementId('r1')};
      final expanded = GroupUtils.expandToGroup(scene, ids, 'g1');
      expect(expanded, hasLength(1));
    });
  });

  group('groupElements', () {
    test('appends groupId to ungrouped elements', () {
      final elements = [_rect(id: 'r1'), _rect(id: 'r2')];
      final grouped = GroupUtils.groupElements(elements, 'g1');
      expect(grouped[0].groupIds, ['g1']);
      expect(grouped[1].groupIds, ['g1']);
    });

    test('appends as outermost to already-grouped elements', () {
      final elements = [
        _rect(id: 'r1', groupIds: ['inner']),
        _rect(id: 'r2', groupIds: ['inner']),
      ];
      final grouped = GroupUtils.groupElements(elements, 'outer');
      expect(grouped[0].groupIds, ['inner', 'outer']);
      expect(grouped[1].groupIds, ['inner', 'outer']);
    });

    test('preserves element properties', () {
      final e = _rect(id: 'r1', x: 42, y: 99);
      final grouped = GroupUtils.groupElements([e], 'g1');
      expect(grouped[0].x, 42);
      expect(grouped[0].y, 99);
      expect(grouped[0].id.value, 'r1');
    });

    test('returns new list — does not mutate originals', () {
      final original = _rect(id: 'r1');
      GroupUtils.groupElements([original], 'g1');
      expect(original.groupIds, isEmpty);
    });
  });

  group('ungroupElements', () {
    test('removes outermost groupId', () {
      final elements = [
        _rect(id: 'r1', groupIds: ['inner', 'outer']),
        _rect(id: 'r2', groupIds: ['inner', 'outer']),
      ];
      final ungrouped = GroupUtils.ungroupElements(elements);
      expect(ungrouped[0].groupIds, ['inner']);
      expect(ungrouped[1].groupIds, ['inner']);
    });

    test('removes the only groupId', () {
      final elements = [
        _rect(id: 'r1', groupIds: ['g1']),
      ];
      final ungrouped = GroupUtils.ungroupElements(elements);
      expect(ungrouped[0].groupIds, isEmpty);
    });

    test('returns element unchanged when no groupIds', () {
      final e = _rect(id: 'r1');
      final ungrouped = GroupUtils.ungroupElements([e]);
      expect(identical(ungrouped[0], e), isTrue);
    });

    test('preserves element properties', () {
      final e = _rect(id: 'r1', x: 10, y: 20, groupIds: ['g1']);
      final ungrouped = GroupUtils.ungroupElements([e]);
      expect(ungrouped[0].x, 10);
      expect(ungrouped[0].y, 20);
    });
  });

  group('resolveGroupForClick', () {
    test('returns null for ungrouped element', () {
      final e = _rect(id: 'r1');
      final scene = Scene().addElement(e);
      expect(
        GroupUtils.resolveGroupForClick(e, {}, scene),
        isNull,
      );
    });

    test('returns outermost group when nothing selected', () {
      final e = _rect(id: 'r1', groupIds: ['inner', 'outer']);
      final scene = Scene()
          .addElement(e)
          .addElement(_rect(id: 'r2', groupIds: ['inner', 'outer']));
      expect(
        GroupUtils.resolveGroupForClick(e, {}, scene),
        'outer',
      );
    });

    test('drills to inner group when outer selected but inner not fully', () {
      // r1 is in both groups, r2 is only in outer, r3 is only in inner
      final r1 = _rect(id: 'r1', groupIds: ['inner', 'outer']);
      final r2 = _rect(id: 'r2', groupIds: ['outer']);
      final r3 = _rect(id: 'r3', groupIds: ['inner']);
      final scene = Scene()
          .addElement(r1)
          .addElement(r2)
          .addElement(r3);

      // Outer fully selected (r1, r2), but inner not (r3 missing)
      final selection = {
        const ElementId('r1'),
        const ElementId('r2'),
      };
      expect(
        GroupUtils.resolveGroupForClick(r1, selection, scene),
        'inner',
      );
    });

    test('returns null when all group levels selected (individual)', () {
      final r1 = _rect(id: 'r1', groupIds: ['g1']);
      final r2 = _rect(id: 'r2', groupIds: ['g1']);
      final scene = Scene().addElement(r1).addElement(r2);

      // All members of the only group are selected
      final selection = {
        const ElementId('r1'),
        const ElementId('r2'),
      };
      expect(
        GroupUtils.resolveGroupForClick(r1, selection, scene),
        isNull,
      );
    });
  });
}
