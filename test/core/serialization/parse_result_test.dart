import 'package:flutter_test/flutter_test.dart';
import 'package:markdraw/src/core/serialization/parse_result.dart';

void main() {
  group('ParseWarning', () {
    test('stores line, message, and context', () {
      const warning = ParseWarning(
        line: 5,
        message: 'Unknown keyword',
        context: 'foo at 10,20',
      );
      expect(warning.line, 5);
      expect(warning.message, 'Unknown keyword');
      expect(warning.context, 'foo at 10,20');
    });

    test('context defaults to null', () {
      const warning = ParseWarning(line: 1, message: 'error');
      expect(warning.context, isNull);
    });

    test('toString includes line and message', () {
      const warning = ParseWarning(line: 3, message: 'bad input');
      expect(warning.toString(), contains('3'));
      expect(warning.toString(), contains('bad input'));
    });

    test('equality based on line, message, context', () {
      const a = ParseWarning(line: 1, message: 'x', context: 'c');
      const b = ParseWarning(line: 1, message: 'x', context: 'c');
      const c = ParseWarning(line: 2, message: 'x', context: 'c');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ParseResult', () {
    test('stores value and empty warnings', () {
      final result = ParseResult(value: 42);
      expect(result.value, 42);
      expect(result.warnings, isEmpty);
    });

    test('stores value and warnings', () {
      final warnings = [const ParseWarning(line: 1, message: 'warn')];
      final result = ParseResult(value: 'hello', warnings: warnings);
      expect(result.value, 'hello');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.message, 'warn');
    });

    test('hasWarnings returns false when no warnings', () {
      final result = ParseResult(value: true);
      expect(result.hasWarnings, isFalse);
    });

    test('hasWarnings returns true when warnings present', () {
      final result = ParseResult(
        value: true,
        warnings: [const ParseWarning(line: 1, message: 'w')],
      );
      expect(result.hasWarnings, isTrue);
    });

    test('warnings list is unmodifiable', () {
      final result = ParseResult(
        value: 0,
        warnings: [const ParseWarning(line: 1, message: 'w')],
      );
      expect(
        () => result.warnings.add(const ParseWarning(line: 2, message: 'x')),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
