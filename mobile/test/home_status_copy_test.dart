import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/home/presentation/pages/home_page.dart';
import 'package:pomodoro_app/features/timer/domain/pomodoro_state.dart';

void main() {
  test('geçici zamanlayıcı durumları kullanıcı eylemini açıklar', () {
    expect(
      timerStatusTitle(TimerStatus.starting, PomodoroPhase.focus),
      'Odak başlatılıyor…',
    );
    expect(
      timerStatusTitle(TimerStatus.cancelling, PomodoroPhase.focus),
      'Odak iptal ediliyor…',
    );
    expect(
      timerStatusTitle(TimerStatus.completing, PomodoroPhase.focus),
      'Odak tamamlanıyor…',
    );
  });

  test('kullanıcı metinlerinde sunucu ve eşitleme jargonu bulunmaz', () {
    for (final phase in PomodoroPhase.values) {
      for (final status in TimerStatus.values) {
        final copy = '${timerStatusTitle(status, phase)} '
            '${timerPrimaryAction(status, phase)}'
            .toLowerCase();
        expect(copy, isNot(contains('sunucu')));
        expect(copy, isNot(contains('eşit')));
      }
    }
  });
}
