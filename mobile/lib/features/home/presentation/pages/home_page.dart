import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/presentation/widgets/app_state_view.dart';
import '../../../../shared/presentation/widgets/responsive_content.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../statistics/application/statistics_controller.dart';
import '../../../statistics/domain/statistics_summary.dart';
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
    ref.invalidate(statisticsControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final statisticsState = ref.watch(statisticsControllerProvider);
    ref.listen(pomodoroControllerProvider, (previous, next) {
      final message = pomodoroCompletionMessage(previous, next);
      if (message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Tamam', onPressed: () {}),
        ),
      );
    });

    return AppAsyncValueView<UserSettings>(
      value: settingsState,
      loadingLabel: 'Ayarlar yükleniyor…',
      errorMessage: (error) =>
          error is AppException ? error.message : error.toString(),
      onRetry: () => ref.read(settingsControllerProvider.notifier).refresh(),
      data: (settings) =>
          _TimerWorkspace(settings: settings, statistics: statisticsState),
    );
  }
}

class _TimerWorkspace extends ConsumerStatefulWidget {
  const _TimerWorkspace({required this.settings, required this.statistics});

  final UserSettings settings;
  final AsyncValue<StatisticsSummary> statistics;

  @override
  ConsumerState<_TimerWorkspace> createState() => _TimerWorkspaceState();
}

class _TimerWorkspaceState extends ConsumerState<_TimerWorkspace> {
  @override
  void initState() {
    super.initState();
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant _TimerWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _configureTimer();
    }
  }

  void _configureTimer() {
    Future.microtask(
      () => ref
          .read(pomodoroControllerProvider.notifier)
          .initialize(widget.settings),
    );
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
    _ensureDailyCountIsSynchronized(timer);

    return ResponsiveContent(
      maxWidth: 760,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PhaseRail(
                activePhase: timer.phase,
                enabled: timer.status == TimerStatus.idle,
                onSelected: (phase) =>
                    controller.selectPhase(phase, widget.settings),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: constraints.maxWidth < 420 ? 250 : 310,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: Semantics(
                                label:
                                    'Oturum ilerlemesi yüzde '
                                    '${(progress * 100).round()}',
                                child: CircularProgressIndicator(
                                  value: progress.clamp(0, 1),
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AnimatedLabel(
                                  value: _phaseTitle(timer.phase),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Semantics(
                                  liveRegion: false,
                                  label:
                                      '${timer.remainingSeconds ~/ 60} dakika '
                                      '${timer.remainingSeconds % 60} saniye',
                                  child: ExcludeSemantics(
                                    child: Text(
                                      _formatDuration(timer.remainingSeconds),
                                      key: const Key('pomodoro-countdown'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -2.4,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _AnimatedLabel(
                                  value: timerStatusTitle(
                                    timer.status,
                                    timer.phase,
                                  ),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _TimerActions(
                        phase: timer.phase,
                        status: timer.status,
                        isActive: timer.isActive,
                        onPrimary: timer.isBusy
                            ? null
                            : timer.status == TimerStatus.running
                            ? controller.pause
                            : () => controller.start(widget.settings),
                        onCancel: timer.isActive
                            ? () => controller.cancel(widget.settings)
                            : null,
                        onSkipBreak:
                            !timer.isActive &&
                                timer.status == TimerStatus.idle &&
                                timer.phase != PomodoroPhase.focus
                            ? () => controller.skipBreak(widget.settings)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _TaskSelector(
                tasks: tasks,
                selectedTaskId: timer.selectedTaskId,
                enabled:
                    !timer.isActive &&
                    !timer.isBusy &&
                    timer.phase == PomodoroPhase.focus,
                onChanged: controller.selectTask,
              ),
              if (timer.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  timer.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _DailyFocusSummary(
                statistics: widget.statistics,
                localCount: timer.dailyCompletedFocusCount,
                longBreakInterval: widget.settings.longBreakInterval,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureDailyCountIsSynchronized(PomodoroState timer) {
    final summary = widget.statistics.value;
    if (widget.statistics.isLoading ||
        summary == null ||
        summary.isOffline ||
        summary.dailyCompletedPomodoros == timer.dailyCompletedFocusCount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestStatistics = ref.read(statisticsControllerProvider);
      final latestSummary = latestStatistics.value;
      if (latestStatistics.isLoading ||
          latestSummary == null ||
          latestSummary.isOffline) {
        return;
      }
      ref
          .read(pomodoroControllerProvider.notifier)
          .syncDailyCompletedFocusCount(latestSummary.dailyCompletedPomodoros);
    });
  }
}

class _DailyFocusSummary extends StatelessWidget {
  const _DailyFocusSummary({
    required this.statistics,
    required this.localCount,
    required this.longBreakInterval,
  });

  final AsyncValue<StatisticsSummary> statistics;
  final int localCount;
  final int longBreakInterval;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = statistics.value;
    final isOffline = summary?.isOffline ?? false;
    final remoteCount = isOffline ? null : summary?.dailyCompletedPomodoros;
    final isInitialLoading =
        statistics.isLoading && remoteCount == null && localCount == 0;
    final hasRemoteError = statistics.hasError && remoteCount == null;
    final hasWarning = isOffline || hasRemoteError;
    final displayCount = statistics.isLoading
        ? localCount
        : remoteCount ?? localCount;

    final label = isInitialLoading
        ? 'Bugünkü odak sayısı yükleniyor…'
        : isOffline
        ? localCount == 0
              ? 'Bugünkü odak sayısı çevrimdışıyken doğrulanamadı'
              : '$localCount odak bu oturumda tamamlandı · '
                    'Günlük toplam çevrimdışı'
        : hasRemoteError
        ? localCount == 0
              ? 'Bugünkü odak sayısı alınamadı'
              : '$localCount odak bu oturumda tamamlandı · '
                    'Günlük toplam alınamadı'
        : '$displayCount odak bugün tamamlandı · '
              'Uzun mola her $longBreakInterval odakta';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasWarning
              ? isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.warning_amber_rounded
              : Icons.check_circle_outline_rounded,
          size: 20,
          color: hasWarning ? colorScheme.error : colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasWarning
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseRail extends StatelessWidget {
  const _PhaseRail({
    required this.activePhase,
    required this.enabled,
    required this.onSelected,
  });

  final PomodoroPhase activePhase;
  final bool enabled;
  final ValueChanged<PomodoroPhase> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final phase in PomodoroPhase.values) ...[
          if (phase != PomodoroPhase.values.first)
            const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Semantics(
              label: '${_shortPhaseTitle(phase)} aşamasına geç',
              button: true,
              selected: phase == activePhase,
              enabled: enabled,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled && phase != activePhase
                      ? () => onSelected(phase)
                      : null,
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    curve: AppMotion.enterCurve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: phase == activePhase
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Text(
                      _shortPhaseTitle(phase),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: phase == activePhase
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: phase == activePhase
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimerActions extends StatelessWidget {
  const _TimerActions({
    required this.phase,
    required this.status,
    required this.isActive,
    required this.onPrimary,
    required this.onCancel,
    required this.onSkipBreak,
  });

  final PomodoroPhase phase;
  final TimerStatus status;
  final bool isActive;
  final VoidCallback? onPrimary;
  final VoidCallback? onCancel;
  final VoidCallback? onSkipBreak;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: FilledButton.icon(
            onPressed: onPrimary,
            icon: AnimatedSwitcher(
              duration: AppMotion.resolve(context, AppMotion.fast),
              reverseDuration: AppMotion.resolve(
                context,
                const Duration(milliseconds: 120),
              ),
              switchInCurve: AppMotion.enterCurve,
              switchOutCurve: AppMotion.exitCurve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(switch (status) {
                TimerStatus.syncing ||
                TimerStatus.starting => Icons.hourglass_top_rounded,
                TimerStatus.cancelling => Icons.close_rounded,
                TimerStatus.completing => Icons.check_rounded,
                TimerStatus.running => Icons.pause_rounded,
                _ => Icons.play_arrow_rounded,
              }, key: ValueKey(status)),
            ),
            label: Text(timerPrimaryAction(status, phase)),
          ),
        ),
        if (isActive || onSkipBreak != null)
          SizedBox(
            width: 170,
            child: OutlinedButton.icon(
              onPressed: isActive ? onCancel : onSkipBreak,
              icon: Icon(
                phase == PomodoroPhase.focus
                    ? Icons.close_rounded
                    : Icons.skip_next_rounded,
              ),
              label: Text(
                phase == PomodoroPhase.focus ? 'Odağı iptal et' : 'Molayı atla',
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedLabel extends StatelessWidget {
  const _AnimatedLabel({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.standard),
      reverseDuration: AppMotion.resolve(context, AppMotion.fast),
      switchInCurve: AppMotion.enterCurve,
      switchOutCurve: AppMotion.exitCurve,
      child: Text(
        value,
        key: ValueKey(value),
        textAlign: TextAlign.center,
        style: style,
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
              '${task.title}  (${task.completedPomodoros} odak · '
              '${task.estimatedPomodoros} tahmin)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: enabled ? onChanged : null,
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

String _shortPhaseTitle(PomodoroPhase phase) => switch (phase) {
  PomodoroPhase.focus => 'Odak',
  PomodoroPhase.shortBreak => 'Kısa mola',
  PomodoroPhase.longBreak => 'Uzun mola',
};

@visibleForTesting
String timerStatusTitle(TimerStatus status, PomodoroPhase phase) =>
    switch (status) {
  TimerStatus.idle => 'Başlamaya hazır',
  TimerStatus.syncing => 'Oturumun hazırlanıyor…',
  TimerStatus.starting =>
    phase == PomodoroPhase.focus
        ? 'Odak başlatılıyor…'
        : 'Mola başlatılıyor…',
  TimerStatus.running => 'Devam ediyor',
  TimerStatus.paused => 'Duraklatıldı',
  TimerStatus.cancelling =>
    phase == PomodoroPhase.focus
        ? 'Odak iptal ediliyor…'
        : 'Mola atlanıyor…',
  TimerStatus.completing =>
    phase == PomodoroPhase.focus
        ? 'Odak tamamlanıyor…'
        : 'Mola tamamlanıyor…',
};

@visibleForTesting
String timerPrimaryAction(TimerStatus status, PomodoroPhase phase) =>
    switch (status) {
      TimerStatus.idle =>
        phase == PomodoroPhase.focus ? 'Odağı başlat' : 'Molayı başlat',
      TimerStatus.syncing => 'Hazırlanıyor…',
      TimerStatus.starting => 'Başlatılıyor…',
      TimerStatus.running => 'Duraklat',
      TimerStatus.paused => 'Devam et',
      TimerStatus.cancelling =>
        phase == PomodoroPhase.focus ? 'İptal ediliyor…' : 'Atlanıyor…',
      TimerStatus.completing => 'Tamamlanıyor…',
    };

@visibleForTesting
String? pomodoroCompletionMessage(
  PomodoroState? previous,
  PomodoroState next,
) {
  final isCompletedSessionTransition =
      previous != null &&
      previous.status == TimerStatus.completing &&
      previous.phase != next.phase &&
      next.status == TimerStatus.idle;
  if (!isCompletedSessionTransition) return null;

  return switch (next.phase) {
    PomodoroPhase.focus => 'Mola tamamlandı. Odak zamanı!',
    PomodoroPhase.shortBreak => 'Odak tamamlandı. Kısa mola zamanı!',
    PomodoroPhase.longBreak => 'Odak tamamlandı. Uzun mola zamanı!',
  };
}
