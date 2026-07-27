import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../application/statistics_controller.dart';
import '../../domain/statistics_summary.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is AppException
              ? error.message
              : 'İstatistikler yüklenemedi.',
          onRetry: () =>
              ref.read(statisticsControllerProvider.notifier).refresh(),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () =>
              ref.read(statisticsControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (summary.isOffline)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Çevrimdışı veriler gösteriliyor'),
                    subtitle: Text(
                      'Bağlantı gelince aşağı çekerek yenileyebilirsin.',
                    ),
                  ),
                ),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _MetricCard(
                    label: 'Bugün odak',
                    value: _formatDuration(summary.dailyFocusSeconds),
                    icon: Icons.today_rounded,
                  ),
                  _MetricCard(
                    label: 'Bu hafta',
                    value: _formatDuration(summary.weeklyFocusSeconds),
                    icon: Icons.date_range_rounded,
                  ),
                  _MetricCard(
                    label: 'Bugün tamamlanan',
                    value: '${summary.dailyCompletedPomodoros}',
                    icon: Icons.check_circle_outline,
                  ),
                  _MetricCard(
                    label: 'Haftalık Pomodoro',
                    value: '${summary.weeklyCompletedPomodoros}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Görev bazlı ilerleme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (summary.taskProgress.isEmpty)
                const Card(
                  child: ListTile(title: Text('Henüz görev ilerlemesi yok.')),
                )
              else
                ...summary.taskProgress.map(_TaskProgressCard.new),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _TaskProgressCard extends StatelessWidget {
  const _TaskProgressCard(this.task);
  final TaskProgress task;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${task.completedPomodoros}/${task.estimatedPomodoros}'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: task.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 52),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}s ${minutes}dk' : '$minutes dk';
}
