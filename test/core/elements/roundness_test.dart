import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/elements/roundness.dart';

void main() {
  group('Roundness', () {
    test('adaptive factory constructs with type adaptive', () {
      const r = Roundness.adaptive(value: 10.0);
      expect(r.type, RoundnessType.adaptive);
      expect(r.value, 10.0);
    });

    test('proportional factory constructs with type proportional', () {
      const r = Roundness.proportional(value: 0.5);
      expect(r.type, RoundnessType.proportional);
      expect(r.value, 0.5);
    });

    test('equality', () {
      const a = Roundness.adaptive(value: 10.0);
      const b = Roundness.adaptive(value: 10.0);
      const c = Roundness.proportional(value: 10.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = Roundness.adaptive(value: 10.0);
      const b = Roundness.adaptive(value: 10.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const r = Roundness.adaptive(value: 10.0);
      expect(r.toString(), 'Roundness(adaptive, 10.0)');
    });
  });

  group('RoundnessType', () {
    test('has two variants', () {
      expect(RoundnessType.values.length, 2);
    });
  });
}
