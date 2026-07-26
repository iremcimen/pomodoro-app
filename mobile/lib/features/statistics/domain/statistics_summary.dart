class TaskProgress {
  const TaskProgress({
    required this.taskId,
    required this.title,
    required this.estimatedPomodoros,
    required this.completedPomodoros,
    required this.isCompleted,
  });

  final int taskId;
  final String title;
  final int estimatedPomodoros;
  final int completedPomodoros;
  final bool isCompleted;

  double get progress => estimatedPomodoros <= 0
      ? (completedPomodoros > 0 ? 1 : 0)
      : (completedPomodoros / estimatedPomodoros).clamp(0, 1);

  factory TaskProgress.fromJson(Map<String, dynamic> json) => TaskProgress(
    taskId: json['task_id'] as int,
    title: json['title'] as String,
    estimatedPomodoros: json['estimated_pomodoros'] as int,
    completedPomodoros: json['completed_pomodoros'] as int,
    isCompleted: json['is_completed'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'title': title,
    'estimated_pomodoros': estimatedPomodoros,
    'completed_pomodoros': completedPomodoros,
    'is_completed': isCompleted,
  };
}

class StatisticsSummary {
  const StatisticsSummary({
    required this.dailyFocusSeconds,
    required this.weeklyFocusSeconds,
    required this.dailyCompletedPomodoros,
    required this.weeklyCompletedPomodoros,
    required this.taskProgress,
    required this.isOffline,
  });

  final int dailyFocusSeconds;
  final int weeklyFocusSeconds;
  final int dailyCompletedPomodoros;
  final int weeklyCompletedPomodoros;
  final List<TaskProgress> taskProgress;
  final bool isOffline;

  factory StatisticsSummary.fromJson(
    Map<String, dynamic> json, {
    bool isOffline = false,
  }) => StatisticsSummary(
    dailyFocusSeconds: json['daily_focus_seconds'] as int,
    weeklyFocusSeconds: json['weekly_focus_seconds'] as int,
    dailyCompletedPomodoros: json['daily_completed_pomodoros'] as int,
    weeklyCompletedPomodoros: json['weekly_completed_pomodoros'] as int,
    taskProgress: (json['task_progress'] as List<dynamic>)
        .map((item) => TaskProgress.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    isOffline: isOffline,
  );

  Map<String, dynamic> toJson() => {
    'daily_focus_seconds': dailyFocusSeconds,
    'weekly_focus_seconds': weeklyFocusSeconds,
    'daily_completed_pomodoros': dailyCompletedPomodoros,
    'weekly_completed_pomodoros': weeklyCompletedPomodoros,
    'task_progress': taskProgress.map((item) => item.toJson()).toList(),
  };
}
