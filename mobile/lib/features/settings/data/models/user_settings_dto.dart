import '../../domain/entities/user_settings.dart';

abstract final class UserSettingsDto {
  static UserSettings fromJson(Map<String, dynamic> json) => UserSettings(
    focusDurationMinutes: _integer(json, 'focus_duration_minutes'),
    shortBreakMinutes: _integer(json, 'short_break_minutes'),
    longBreakMinutes: _integer(json, 'long_break_minutes'),
    longBreakInterval: _integer(json, 'long_break_interval'),
    autoStartBreak: _boolean(json, 'auto_start_break'),
    autoStartFocus: _boolean(json, 'auto_start_focus'),
    soundEnabled: _boolean(json, 'sound_enabled'),
    vibrationEnabled: _boolean(json, 'vibration_enabled'),
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
  );

  static Map<String, dynamic> toPatchJson(UserSettings settings) => {
    'focus_duration_minutes': settings.focusDurationMinutes,
    'short_break_minutes': settings.shortBreakMinutes,
    'long_break_minutes': settings.longBreakMinutes,
    'long_break_interval': settings.longBreakInterval,
    'auto_start_break': settings.autoStartBreak,
    'auto_start_focus': settings.autoStartFocus,
    'sound_enabled': settings.soundEnabled,
    'vibration_enabled': settings.vibrationEnabled,
  };

  static int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('$key alanı geçersiz.');
  }

  static bool _boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw FormatException('$key alanı geçersiz.');
  }
}
