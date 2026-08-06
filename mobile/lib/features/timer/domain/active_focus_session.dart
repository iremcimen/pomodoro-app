import 'pomodoro_state.dart';

class ActiveFocusSession {
  const ActiveFocusSession({
    required this.id,
    required this.phase,
    required this.plannedSeconds,
    required this.startedAt,
    this.taskId,
  });

  factory ActiveFocusSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final sessionType = json['session_type'];
    final status = json['status'];
    final plannedSeconds = json['planned_duration_seconds'];
    final startedAtValue = json['started_at'];
    final taskId = json['task_id'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing focus session id.');
    }
    if (status != 'started') {
      throw const FormatException('Focus session is not active.');
    }
    if (plannedSeconds is! int || plannedSeconds <= 0) {
      throw const FormatException('Invalid planned focus session duration.');
    }
    if (taskId != null && taskId is! int) {
      throw const FormatException('Invalid focus session task id.');
    }

    final startedAt = startedAtValue is String
        ? DateTime.tryParse(startedAtValue)
        : null;
    if (startedAt == null) {
      throw const FormatException('Invalid focus session start time.');
    }

    final phase = switch (sessionType) {
      'focus' => PomodoroPhase.focus,
      'short_break' => PomodoroPhase.shortBreak,
      'long_break' => PomodoroPhase.longBreak,
      _ => throw const FormatException('Invalid focus session type.'),
    };

    return ActiveFocusSession(
      id: id,
      phase: phase,
      plannedSeconds: plannedSeconds,
      startedAt: startedAt.toUtc(),
      taskId: taskId as int?,
    );
  }

  final String id;
  final PomodoroPhase phase;
  final int plannedSeconds;
  final DateTime startedAt;
  final int? taskId;

  int remainingSecondsAt(DateTime now) {
    final endsAt = startedAt.add(Duration(seconds: plannedSeconds));
    return remainingSecondsUntil(endsAt, now.toUtc()).clamp(0, plannedSeconds);
  }
}
