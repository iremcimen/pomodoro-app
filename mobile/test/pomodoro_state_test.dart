import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/timer/domain/pomodoro_state.dart';

void main() {
  test('arka plandan dönüşte süreyi bitiş zamanından hesaplar', () {
    final now = DateTime.utc(2026, 7, 26, 12);
    final endsAt = now.add(const Duration(minutes: 12, milliseconds: 100));
    expect(remainingSecondsUntil(endsAt, now), 721);
    expect(
      remainingSecondsUntil(endsAt, endsAt.add(const Duration(seconds: 5))),
      0,
    );
  });

  test('uzun mola ayarlanan odak aralığında seçilir', () {
    expect(
      nextPomodoroPhase(
        completedPhase: PomodoroPhase.focus,
        completedFocusCount: 3,
        longBreakInterval: 4,
      ),
      PomodoroPhase.shortBreak,
    );
    expect(
      nextPomodoroPhase(
        completedPhase: PomodoroPhase.focus,
        completedFocusCount: 4,
        longBreakInterval: 4,
      ),
      PomodoroPhase.longBreak,
    );
    expect(
      nextPomodoroPhase(
        completedPhase: PomodoroPhase.shortBreak,
        completedFocusCount: 4,
        longBreakInterval: 4,
      ),
      PomodoroPhase.focus,
    );
  });
}
