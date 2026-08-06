import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/presentation/widgets/app_state_view.dart';
import '../../../../shared/presentation/widgets/responsive_content.dart';
import '../../application/statistics_controller.dart';
import '../../domain/statistics_summary.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsControllerProvider);

    return AppAsyncValueView<StatisticsSummary>(
      value: state,
      loadingLabel: 'İstatistikler yükleniyor…',
      errorMessage: (error) =>
          error is AppException ? error.message : 'İstatistikler yüklenemedi.',
      onRetry: () => ref.read(statisticsControllerProvider.notifier).refresh(),
      data: (summary) => ResponsiveContent(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(statisticsControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              if (summary.isOffline) ...[
                _OfflineNotice(
                  onRefresh: () =>
                      ref.read(statisticsControllerProvider.notifier).refresh(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _OverviewPanel(summary: summary),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Görev bazlı ilerleme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.taskProgress.isEmpty)
                const Card(
                  child: AppStateMessage(
                    icon: Icons.insights_outlined,
                    title: 'Henüz görev ilerlemesi yok',
                    description:
                        'Bir göreve bağlı odak oturumu tamamladığında '
                        'ilerlemen burada görünür.',
                  ),
                )
              else
                _TaskProgressList(tasks: summary.taskProgress),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: ListTile(
        leading: Icon(
          Icons.cloud_off_outlined,
          color: colorScheme.onSecondaryContainer,
        ),
        title: const Text('Çevrimdışı veriler gösteriliyor'),
        subtitle: const Text('Bağlantı geldiğinde verileri yenileyebilirsin.'),
        trailing: IconButton(
          tooltip: 'Verileri yenile',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.summary});

  final StatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'Bugün odak',
        value: _formatDuration(summary.dailyFocusSeconds),
        icon: Icons.today_rounded,
      ),
      _MetricData(
        label: 'Bu hafta',
        value: _formatDuration(summary.weeklyFocusSeconds),
        icon: Icons.date_range_rounded,
      ),
      _MetricData(
        label: 'Bugünkü Pomodoro',
        value: '${summary.dailyCompletedPomodoros}',
        icon: Icons.check_circle_outline,
      ),
      _MetricData(
        label: 'Haftalık Pomodoro',
        value: '${summary.weeklyCompletedPomodoros}',
        icon: Icons.local_fire_department_outlined,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Odak özeti', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 680 ? 4 : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.lg,
                    childAspectRatio: columns == 4 ? 1.35 : 1.25,
                  ),
                  itemCount: metrics.length,
                  itemBuilder: (context, index) =>
                      _MetricCell(metric: metrics[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(metric.icon, size: 22, color: theme.colorScheme.primary),
        const Spacer(),
        Text(metric.value, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          metric.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TaskProgressList extends StatelessWidget {
  const _TaskProgressList({required this.tasks});

  final List<TaskProgress> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            _TaskProgressRow(task: tasks[index]),
            if (index != tasks.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskProgressRow extends StatelessWidget {
  const _TaskProgressRow({required this.task});

  final TaskProgress task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              const SizedBox(width: AppSpacing.md),
              Text(
                '${task.completedPomodoros} odak · '
                '${task.estimatedPomodoros} tahmin',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label:
                '${task.title}: ${task.completedPomodoros} odak tamamlandı, '
                '${task.estimatedPomodoros} odak tahmin edildi',
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}s ${minutes}dk' : '$minutes dk';
}
