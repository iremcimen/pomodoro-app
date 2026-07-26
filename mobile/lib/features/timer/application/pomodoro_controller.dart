import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../settings/domain/entities/user_settings.dart';
import '../../tasks/application/task_providers.dart';
import '../../statistics/application/statistics_controller.dart';
import '../domain/pomodoro_state.dart';
import 'timer_providers.dart';
import 'session_feedback_service.dart';

final pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _ticker;
  bool _finishing = false;

  @override
  PomodoroState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PomodoroState(
      phase: PomodoroPhase.focus,
      status: TimerStatus.idle,
      remainingSeconds: 25 * 60,
      plannedSeconds: 25 * 60,
      completedFocusCount: 0,
    );
  }

  void configure(UserSettings settings) {
    if (state.status != TimerStatus.idle) return;
    final seconds = _durationFor(state.phase, settings);
    if (state.plannedSeconds == seconds) return;
    state = state.copyWith(plannedSeconds: seconds, remainingSeconds: seconds);
  }

  void selectTask(int? taskId) {
    if (state.isActive || state.phase != PomodoroPhase.focus) return;
    state = taskId == null
        ? state.copyWith(clearSelectedTask: true)
        : state.copyWith(selectedTaskId: taskId);
  }

  Future<void> start(UserSettings settings) async {
    if (state.status == TimerStatus.completing) return;
    if (state.status == TimerStatus.paused) {
      if (state.remainingSeconds == 0) {
        await _finish(settings);
      } else {
        resume(settings);
      }
      return;
    }
    if (state.status != TimerStatus.idle) return;

    final planned = _durationFor(state.phase, settings);
    final startedAt = DateTime.now().toUtc();
    final sessionId = _newUuid();
    state = state.copyWith(
      status: TimerStatus.completing,
      plannedSeconds: planned,
      remainingSeconds: planned,
      sessionId: sessionId,
      startedAt: startedAt,
      clearError: true,
    );

    try {
      await ref
          .read(focusSessionRemoteDataSourceProvider)
          .start(
            id: sessionId,
            phase: state.phase,
            plannedSeconds: planned,
            startedAt: startedAt,
            taskId: state.selectedTaskId,
          );
    } on Object catch (error) {
      state = state.copyWith(
        status: TimerStatus.idle,
        clearSession: true,
        errorMessage: _message(error),
      );
      return;
    }

    state = state.copyWith(
      status: TimerStatus.running,
      endsAt: DateTime.now().add(Duration(seconds: planned)),
    );
    _startTicker(settings);
  }

  void pause() {
    if (state.status != TimerStatus.running) return;
    _syncRemaining();
    _ticker?.cancel();
    state = state.copyWith(status: TimerStatus.paused, clearEndsAt: true);
  }

  void resume(UserSettings settings) {
    if (state.status != TimerStatus.paused || state.remainingSeconds <= 0) {
      return;
    }
    state = state.copyWith(
      status: TimerStatus.running,
      endsAt: DateTime.now().add(Duration(seconds: state.remainingSeconds)),
      clearError: true,
    );
    _startTicker(settings);
  }

  Future<void> cancel(UserSettings settings) async {
    if (!state.isActive || state.sessionId == null) return;
    if (state.status == TimerStatus.running) _syncRemaining();
    _ticker?.cancel();
    final actual = state.plannedSeconds - state.remainingSeconds;
    final sessionId = state.sessionId!;
    state = state.copyWith(status: TimerStatus.completing);
    try {
      await ref
          .read(focusSessionRemoteDataSourceProvider)
          .cancel(sessionId, actual.clamp(0, state.plannedSeconds));
      _resetCurrentPhase(settings);
    } on Object catch (error) {
      state = state.copyWith(
        status: TimerStatus.paused,
        clearEndsAt: true,
        errorMessage: _message(error),
      );
    }
  }

  void syncAfterLifecycle(UserSettings settings) {
    if (state.status != TimerStatus.running) return;
    _syncRemaining();
    if (state.remainingSeconds == 0) unawaited(_finish(settings));
  }

  void _startTicker(UserSettings settings) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRemaining();
      if (state.remainingSeconds == 0) {
        _ticker?.cancel();
        unawaited(_finish(settings));
      }
    });
  }

  void _syncRemaining() {
    final endsAt = state.endsAt;
    if (endsAt == null) return;
    final remaining = remainingSecondsUntil(endsAt, DateTime.now());
    if (remaining != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: remaining);
    }
  }

  Future<void> _finish(UserSettings settings) async {
    if (_finishing || state.sessionId == null) return;
    _finishing = true;
    _ticker?.cancel();
    final completedPhase = state.phase;
    final sessionId = state.sessionId!;
    state = state.copyWith(status: TimerStatus.completing, remainingSeconds: 0);
    try {
      await ref
          .read(focusSessionRemoteDataSourceProvider)
          .complete(sessionId, state.plannedSeconds);
      final focusCount = completedPhase == PomodoroPhase.focus
          ? state.completedFocusCount + 1
          : state.completedFocusCount;
      final nextPhase = nextPomodoroPhase(
        completedPhase: completedPhase,
        completedFocusCount: focusCount,
        longBreakInterval: settings.longBreakInterval,
      );
      final nextSeconds = _durationFor(nextPhase, settings);
      state = state.copyWith(
        phase: nextPhase,
        status: TimerStatus.idle,
        remainingSeconds: nextSeconds,
        plannedSeconds: nextSeconds,
        completedFocusCount: focusCount,
        clearSession: true,
        clearEndsAt: true,
        clearError: true,
      );
      await ref.read(sessionFeedbackServiceProvider).sessionCompleted(settings);
      if (completedPhase == PomodoroPhase.focus) {
        ref.invalidate(taskControllerProvider);
        ref.invalidate(statisticsControllerProvider);
      }
      final shouldAutoStart = nextPhase == PomodoroPhase.focus
          ? settings.autoStartFocus
          : settings.autoStartBreak;
      if (shouldAutoStart) await start(settings);
    } on Object catch (error) {
      state = state.copyWith(
        status: TimerStatus.paused,
        clearEndsAt: true,
        errorMessage: _message(error),
      );
    } finally {
      _finishing = false;
    }
  }

  void _resetCurrentPhase(UserSettings settings) {
    final seconds = _durationFor(state.phase, settings);
    state = state.copyWith(
      status: TimerStatus.idle,
      remainingSeconds: seconds,
      plannedSeconds: seconds,
      clearSession: true,
      clearEndsAt: true,
      clearError: true,
    );
  }

  int _durationFor(PomodoroPhase phase, UserSettings settings) =>
      switch (phase) {
        PomodoroPhase.focus => settings.focusDurationMinutes * 60,
        PomodoroPhase.shortBreak => settings.shortBreakMinutes * 60,
        PomodoroPhase.longBreak => settings.longBreakMinutes * 60,
      };

  String _message(Object error) =>
      error is AppException ? error.message : 'Oturum kaydedilemedi.';

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
