import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/core/validation/input_validators.dart';

void main() {
  group('InputValidators', () {
    test('accepts a valid email or backend-compatible username', () {
      expect(InputValidators.loginIdentifier('user@example.com'), isNull);
      expect(InputValidators.loginIdentifier('pomo_user_1'), isNull);
    });

    test('rejects usernames outside the backend contract', () {
      expect(InputValidators.username('AB'), isNotNull);
      expect(InputValidators.username('UpperCase'), isNull);
      expect(InputValidators.username('dash-user'), isNotNull);
      expect(InputValidators.username('space user'), isNotNull);
    });

    test('enforces the backend password limits', () {
      expect(InputValidators.password('1234567'), isNotNull);
      expect(InputValidators.password('12345678'), isNull);
      expect(InputValidators.password('a' * 129), isNotNull);
    });
  });
}
