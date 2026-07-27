class UserSettings {
  const UserSettings({
    required this.focusDurationMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.longBreakInterval,
    required this.autoStartBreak,
    required this.autoStartFocus,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.updatedAt,
  });

  static const defaults = UserSettings(
    focusDurationMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    longBreakInterval: 4,
    autoStartBreak: false,
    autoStartFocus: false,
    soundEnabled: true,
    vibrationEnabled: true,
    updatedAt: null,
  );

  final int focusDurationMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval;
  final bool autoStartBreak;
  final bool autoStartFocus;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final DateTime? updatedAt;

  UserSettings copyWith({
    int? focusDurationMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakInterval,
    bool? autoStartBreak,
    bool? autoStartFocus,
    bool? soundEnabled,
    bool? vibrationEnabled,
    DateTime? updatedAt,
  }) => UserSettings(
    focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    longBreakInterval: longBreakInterval ?? this.longBreakInterval,
    autoStartBreak: autoStartBreak ?? this.autoStartBreak,
    autoStartFocus: autoStartFocus ?? this.autoStartFocus,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
