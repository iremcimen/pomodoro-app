import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/tasks/domain/entities/task_item.dart';

void main() {
  test('backend görev yanıtını ve Pomodoro ilerlemesini dönüştürür', () {
    final task = TaskItem.fromJson({
      'id': 7,
      'title': 'Raporu tamamla',
      'description': 'Son kontroller',
      'estimated_pomodoros': 4,
      'completed_pomodoros': 2,
      'is_completed': false,
    });

    expect(task.id, 7);
    expect(task.title, 'Raporu tamamla');
    expect(task.progress, 0.5);
    expect(task.isCompleted, isFalse);
  });

  test('gerçekleşen sayı tahmini aşınca ilerlemeyi yüzde yüzde sınırlar', () {
    final task = TaskItem.fromJson({
      'id': 8,
      'title': 'Araştırma',
      'description': null,
      'estimated_pomodoros': 1,
      'completed_pomodoros': 3,
      'is_completed': true,
    });

    expect(task.progress, 1);
  });
}
