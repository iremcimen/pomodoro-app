import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/home/presentation/pages/home_page.dart';
import 'package:pomodoro_app/features/timer/domain/pomodoro_state.dart';

void main() {
  test('manuel faz değişiminde tamamlanma bildirimi göstermez', () {
    final previous = _state(
      phase: PomodoroPhase.focus,
      status: TimerStatus.idle,
    );
    final next = _state(
      phase: PomodoroPhase.shortBreak,
      status: TimerStatus.idle,
    );

    expect(pomodoroCompletionMessage(previous, next), isNull);
  });

  test('tamamlanan odaktan sonra doğru mola bildirimini gösterir', () {
    final previous = _state(
      phase: PomodoroPhase.focus,
      status: TimerStatus.completing,
    );
    final next = _state(
      phase: PomodoroPhase.shortBreak,
      status: TimerStatus.idle,
    );

    expect(
      pomodoroCompletionMessage(previous, next),
      'Odak tamamlandı. Kısa mola zamanı!',
    );
  });

  test('iptal edilen molayı tamamlanmış gibi göstermez', () {
    final previous = _state(
      phase: PomodoroPhase.shortBreak,
      status: TimerStatus.running,
    );
    final next = _state(
      phase: PomodoroPhase.focus,
      status: TimerStatus.idle,
    );

    expect(pomodoroCompletionMessage(previous, next), isNull);
  });
}

PomodoroState _state({
  required PomodoroPhase phase,
  required TimerStatus status,
}) => PomodoroState(
  phase: phase,
  status: status,
  remainingSeconds: 60,
  plannedSeconds: 60,
  dailyCompletedFocusCount: 0,
);
