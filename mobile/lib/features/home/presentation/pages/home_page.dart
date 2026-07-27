import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/error/app_exception.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../tasks/application/task_providers.dart';
import '../../../tasks/domain/entities/task_item.dart';
import '../../../timer/application/pomodoro_controller.dart';
import '../../../timer/domain/pomodoro_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final settings = ref.read(settingsControllerProvider).value;
    if (settings != null) {
      ref
          .read(pomodoroControllerProvider.notifier)
          .syncAfterLifecycle(settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    ref.listen(pomodoroControllerProvider, (previous, next) {
      if (previous == null || previous.phase == next.phase) return;
      final message = next.phase == PomodoroPhase.focus
          ? 'Mola tamamlandı. Odak zamanı!'
          : next.phase == PomodoroPhase.longBreak
          ? 'Odak tamamlandı. Uzun mola zamanı!'
          : 'Odak tamamlandı. Kısa mola zamanı!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Tamam', onPressed: () {}),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomo'),
        actions: [
          IconButton(
            tooltip: 'İstatistikler',
            onPressed: () => context.push(AppRoutes.statistics),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'Görevler',
            onPressed: () => context.push(AppRoutes.tasks),
            icon: const Icon(Icons.task_alt_outlined),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: settingsState.when(
        loading: () => const Center(child: Text('Ayarlar yükleniyor…')),
        error: (error, _) => _LoadError(
          message: error is AppException ? error.message : error.toString(),
          onRetry: () =>
              ref.read(settingsControllerProvider.notifier).refresh(),
        ),
        data: (settings) => _TimerWorkspace(settings: settings),
      ),
    );
  }
}

class _TimerWorkspace extends ConsumerStatefulWidget {
  const _TimerWorkspace({required this.settings});
  final UserSettings settings;

  @override
  ConsumerState<_TimerWorkspace> createState() => _TimerWorkspaceState();
}

class _TimerWorkspaceState extends ConsumerState<_TimerWorkspace> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(pomodoroControllerProvider.notifier)
          .configure(widget.settings),
    );
  }

  @override
  void didUpdateWidget(covariant _TimerWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      Future.microtask(
        () => ref
            .read(pomodoroControllerProvider.notifier)
            .configure(widget.settings),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(pomodoroControllerProvider);
    final tasks = ref.watch(activeTasksProvider);
    final controller = ref.read(pomodoroControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final progress = timer.plannedSeconds == 0
        ? 0.0
        : 1 - (timer.remainingSeconds / timer.plannedSeconds);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                SegmentedButton<PomodoroPhase>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: PomodoroPhase.focus,
                      label: Text('Odak'),
                    ),
                    ButtonSegment(
                      value: PomodoroPhase.shortBreak,
                      label: Text('Kısa mola'),
                    ),
                    ButtonSegment(
                      value: PomodoroPhase.longBreak,
                      label: Text('Uzun mola'),
                    ),
                  ],
                  selected: {timer.phase},
                  onSelectionChanged: null,
                ),
                const SizedBox(height: 28),
                SizedBox.square(
                  dimension: constraints.maxWidth < 420 ? 260 : 330,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress.clamp(0, 1),
                          strokeWidth: 13,
                          strokeCap: StrokeCap.round,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _phaseTitle(timer.phase),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(timer.remainingSeconds),
                            key: const Key('pomodoro-countdown'),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: 68,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -3,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(_statusTitle(timer.status)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _TaskSelector(
                  tasks: tasks,
                  selectedTaskId: timer.selectedTaskId,
                  enabled:
                      !timer.isActive &&
                      timer.status != TimerStatus.completing &&
                      timer.phase == PomodoroPhase.focus,
                  onChanged: controller.selectTask,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: 190,
                      child: FilledButton.icon(
                        onPressed: timer.status == TimerStatus.completing
                            ? null
                            : timer.status == TimerStatus.running
                            ? controller.pause
                            : () => controller.start(widget.settings),
                        icon: Icon(
                          timer.status == TimerStatus.running
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_primaryAction(timer.status)),
                      ),
                    ),
                    if (timer.isActive)
                      SizedBox(
                        width: 150,
                        child: OutlinedButton.icon(
                          onPressed: () => controller.cancel(widget.settings),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('İptal et'),
                        ),
                      ),
                  ],
                ),
                if (timer.errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    timer.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '${timer.completedFocusCount} odak tamamlandı • '
                  'Uzun mola her ${widget.settings.longBreakInterval} odakta',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskSelector extends StatelessWidget {
  const _TaskSelector({
    required this.tasks,
    required this.selectedTaskId,
    required this.enabled,
    required this.onChanged,
  });

  final AsyncValue<List<TaskItem>> tasks;
  final int? selectedTaskId;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => tasks.when(
    loading: () => const ListTile(
      leading: Icon(Icons.task_alt),
      title: Text('Görevler yükleniyor…'),
    ),
    error: (_, __) => const ListTile(
      leading: Icon(Icons.warning_amber_rounded),
      title: Text('Görevler yüklenemedi'),
    ),
    data: (items) => DropdownButtonFormField<int?>(
      initialValue: items.any((task) => task.id == selectedTaskId)
          ? selectedTaskId
          : null,
      decoration: const InputDecoration(
        labelText: 'Aktif görev',
        prefixIcon: Icon(Icons.task_alt_rounded),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Görevsiz odak')),
        ...items.map(
          (task) => DropdownMenuItem<int?>(
            value: task.id,
            child: Text(
              '${task.title}  (${task.completedPomodoros}/'
              '${task.estimatedPomodoros})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _phaseTitle(PomodoroPhase phase) => switch (phase) {
  PomodoroPhase.focus => 'Odak zamanı',
  PomodoroPhase.shortBreak => 'Kısa mola',
  PomodoroPhase.longBreak => 'Uzun mola',
};

String _statusTitle(TimerStatus status) => switch (status) {
  TimerStatus.idle => 'Başlamaya hazır',
  TimerStatus.running => 'Devam ediyor',
  TimerStatus.paused => 'Duraklatıldı',
  TimerStatus.completing => 'Sunucuyla eşitleniyor…',
};

String _primaryAction(TimerStatus status) => switch (status) {
  TimerStatus.idle => 'Başlat',
  TimerStatus.running => 'Duraklat',
  TimerStatus.paused => 'Devam et',
  TimerStatus.completing => 'Kaydediliyor…',
};
