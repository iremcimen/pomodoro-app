class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedPomodoros,
    required this.completedPomodoros,
    required this.isCompleted,
  });

  final int id;
  final String title;
  final String? description;
  final int estimatedPomodoros;
  final int completedPomodoros;
  final bool isCompleted;

  double get progress => estimatedPomodoros <= 0
      ? (completedPomodoros > 0 ? 1 : 0)
      : (completedPomodoros / estimatedPomodoros).clamp(0, 1);

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    estimatedPomodoros: json['estimated_pomodoros'] as int,
    completedPomodoros: json['completed_pomodoros'] as int,
    isCompleted: json['is_completed'] as bool,
  );
}
