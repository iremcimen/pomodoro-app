import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/statistics/domain/statistics_summary.dart';

void main() {
  test('istatistik özetini ve görev ilerlemesini dönüştürür', () {
    final summary = StatisticsSummary.fromJson({
      'daily_focus_seconds': 1500,
      'weekly_focus_seconds': 7200,
      'daily_completed_pomodoros': 1,
      'weekly_completed_pomodoros': 5,
      'task_progress': [
        {
          'task_id': 4,
          'title': 'Sunum',
          'estimated_pomodoros': 4,
          'completed_pomodoros': 3,
          'is_completed': false,
        },
      ],
    });

    expect(summary.dailyFocusSeconds, 1500);
    expect(summary.weeklyCompletedPomodoros, 5);
    expect(summary.taskProgress.single.progress, 0.75);
    expect(summary.isOffline, isFalse);
  });

  test('cache üzerinden okunan özet çevrimdışı işaretlenir', () {
    final summary = StatisticsSummary.fromJson({
      'daily_focus_seconds': 0,
      'weekly_focus_seconds': 0,
      'daily_completed_pomodoros': 0,
      'weekly_completed_pomodoros': 0,
      'task_progress': <dynamic>[],
    }, isOffline: true);

    expect(summary.isOffline, isTrue);
  });
}
