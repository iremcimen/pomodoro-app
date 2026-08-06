import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/timer/domain/active_focus_session.dart';
import 'package:pomodoro_app/features/timer/domain/pomodoro_state.dart';

void main() {
  test('aktif oturum cevabını zamanlayıcı durumuna dönüştürür', () {
    final session = ActiveFocusSession.fromJson({
      'id': 'd9044ca4-b656-40a2-a2a4-cf2290facbfd',
      'task_id': 42,
      'session_type': 'focus',
      'status': 'started',
      'planned_duration_seconds': 60,
      'started_at': '2026-07-27T10:00:00+03:00',
    });

    expect(session.phase, PomodoroPhase.focus);
    expect(session.taskId, 42);
    expect(session.startedAt, DateTime.utc(2026, 7, 27, 7));
    expect(session.remainingSecondsAt(DateTime.utc(2026, 7, 27, 7, 0, 15)), 45);
    expect(session.remainingSecondsAt(DateTime.utc(2026, 7, 27, 7, 2)), 0);
  });

  test('aktif olmayan veya bozuk oturum cevabını reddeder', () {
    expect(
      () => ActiveFocusSession.fromJson({
        'id': 'session-id',
        'task_id': null,
        'session_type': 'focus',
        'status': 'completed',
        'planned_duration_seconds': 60,
        'started_at': '2026-07-27T07:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
