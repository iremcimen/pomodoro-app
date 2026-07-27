enum PomodoroPhase { focus, shortBreak, longBreak }

enum TimerStatus {
  idle,
  syncing,
  starting,
  running,
  paused,
  cancelling,
  completing,
}

int remainingSecondsUntil(DateTime endsAt, DateTime now) {
  final milliseconds = endsAt.difference(now).inMilliseconds;
  return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
}

PomodoroPhase nextPomodoroPhase({
  required PomodoroPhase completedPhase,
  required int completedFocusCount,
  required int longBreakInterval,
}) {
  if (completedPhase != PomodoroPhase.focus) return PomodoroPhase.focus;
  return completedFocusCount % longBreakInterval == 0
      ? PomodoroPhase.longBreak
      : PomodoroPhase.shortBreak;
}

class PomodoroState {
  const PomodoroState({
    required this.phase,
    required this.status,
    required this.remainingSeconds,
    required this.plannedSeconds,
    required this.dailyCompletedFocusCount,
    this.selectedTaskId,
    this.sessionId,
    this.startedAt,
    this.endsAt,
    this.errorMessage,
  });

  final PomodoroPhase phase;
  final TimerStatus status;
  final int remainingSeconds;
  final int plannedSeconds;
  final int dailyCompletedFocusCount;
  final int? selectedTaskId;
  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? errorMessage;

  bool get isActive =>
      status == TimerStatus.running || status == TimerStatus.paused;

  bool get isBusy =>
      status == TimerStatus.syncing ||
      status == TimerStatus.starting ||
      status == TimerStatus.cancelling ||
      status == TimerStatus.completing;

  PomodoroState copyWith({
    PomodoroPhase? phase,
    TimerStatus? status,
    int? remainingSeconds,
    int? plannedSeconds,
    int? dailyCompletedFocusCount,
    int? selectedTaskId,
    bool clearSelectedTask = false,
    String? sessionId,
    bool clearSession = false,
    DateTime? startedAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
    String? errorMessage,
    bool clearError = false,
  }) => PomodoroState(
    phase: phase ?? this.phase,
    status: status ?? this.status,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    plannedSeconds: plannedSeconds ?? this.plannedSeconds,
    dailyCompletedFocusCount:
        dailyCompletedFocusCount ?? this.dailyCompletedFocusCount,
    selectedTaskId: clearSelectedTask
        ? null
        : selectedTaskId ?? this.selectedTaskId,
    sessionId: clearSession ? null : sessionId ?? this.sessionId,
    startedAt: clearSession ? null : startedAt ?? this.startedAt,
    endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}
