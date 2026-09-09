import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/validators.dart';

void main() {
  group('Validators Test Suite', () {
    test('validateEmail validates correctly', () {
      expect(Validators.validateEmail(null), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
      expect(Validators.validateEmail('user@domain'), isNotNull);
      expect(Validators.validateEmail('user@example.com'), isNull);
      expect(Validators.validateEmail('  john.doe@company.org  '), isNull);
    });

    test('validatePassword validates correctly', () {
      expect(Validators.validatePassword(null), isNotNull);
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('short'), isNotNull);
      expect(Validators.validatePassword('1234567'), isNotNull);
      expect(Validators.validatePassword('password123'), isNull);
      expect(Validators.validatePassword('StrongPass!'), isNull);
    });

    test('validateNewPassword validates correctly', () {
      expect(
        Validators.validateNewPassword('short', 'oldPassword123'),
        isNotNull,
      );
      expect(
        Validators.validateNewPassword('samePassword', 'samePassword'),
        isNotNull,
      );
      expect(
        Validators.validateNewPassword('newPassword123', 'oldPassword123'),
        isNull,
      );
    });

    test('validateName validates correctly', () {
      expect(Validators.validateName(null), isNotNull);
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('a'), isNotNull);
      expect(Validators.validateName('John Doe'), isNull);
    });

    test('validateTeamDescription validates correctly', () {
      expect(Validators.validateTeamDescription(null), isNotNull);
      expect(Validators.validateTeamDescription('abc'), isNotNull);
      expect(
        Validators.validateTeamDescription('Valid description here'),
        isNull,
      );
    });

    test('validateDateRange validates correctly', () {
      final d1 = DateTime(2026, 1, 1);
      final d2 = DateTime(2026, 1, 15);
      expect(Validators.validateDateRange(d1, d2), isNull);
      expect(Validators.validateDateRange(d1, d1), isNull);
      expect(Validators.validateDateRange(d2, d1), isNotNull);
    });
  });
}
