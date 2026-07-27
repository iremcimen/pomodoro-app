import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/settings/data/models/user_settings_dto.dart';
import 'package:pomodoro_app/features/settings/domain/entities/user_settings.dart';

void main() {
  test('backend ayar yanıtını modele dönüştürür', () {
    final settings = UserSettingsDto.fromJson({
      'focus_duration_minutes': 30,
      'short_break_minutes': 6,
      'long_break_minutes': 20,
      'long_break_interval': 3,
      'auto_start_break': true,
      'auto_start_focus': false,
      'sound_enabled': true,
      'vibration_enabled': false,
      'updated_at': '2026-07-26T12:00:00Z',
    });
    expect(settings.focusDurationMinutes, 30);
    expect(settings.autoStartBreak, isTrue);
    expect(settings.updatedAt, DateTime.utc(2026, 7, 26, 12));
  });

  test('ayarları snake_case PATCH gövdesine çevirir', () {
    final json = UserSettingsDto.toPatchJson(UserSettings.defaults);
    expect(json['focus_duration_minutes'], 25);
    expect(json['long_break_interval'], 4);
    expect(json['auto_start_focus'], isFalse);
    expect(json, hasLength(8));
  });
}
