import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../settings/domain/entities/user_settings.dart';
import '../../tasks/application/task_providers.dart';
import '../../statistics/application/statistics_controller.dart';
import '../domain/active_focus_session.dart';
import '../domain/pomodoro_state.dart';
import 'timer_providers.dart';
import 'session_feedback_service.dart';

final pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _ticker;
  bool _finishing = false;
  bool _hasCheckedForActiveSession = false;
  bool _recovering = false;

  @override
  PomodoroState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PomodoroState(
      phase: PomodoroPhase.focus,
      status: TimerStatus.idle,
      remainingSeconds: 25 * 60,
      plannedSeconds: 25 * 60,
      dailyCompletedFocusCount: 0,
    );
  }

  void syncDailyCompletedFocusCount(int count) {
    if (count < 0 || count == state.dailyCompletedFocusCount) return;
    state = state.copyWith(dailyCompletedFocusCount: count);
  }

  Future<void> initialize(UserSettings settings) async {
    configure(settings);
    if (_hasCheckedForActiveSession ||
        state.isActive ||
        state.isBusy) {
      return;
    }

    _hasCheckedForActiveSession = true;
    await _restoreActiveSession(settings);
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

  void selectPhase(PomodoroPhase phase, UserSettings settings) {
    if (state.status != TimerStatus.idle || phase == state.phase) return;
    _setIdlePhase(phase, settings);
  }

  void skipBreak(UserSettings settings) {
    if (state.status != TimerStatus.idle ||
        state.phase == PomodoroPhase.focus) {
      return;
    }
    _setIdlePhase(PomodoroPhase.focus, settings);
  }

  Future<void> start(UserSettings settings) async {
    if (state.isBusy) return;
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
      status: TimerStatus.starting,
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
      if (error is AppException && error.code == 'ACTIVE_SESSION_EXISTS') {
        state = state.copyWith(
          status: TimerStatus.syncing,
          clearSession: true,
          clearEndsAt: true,
          clearError: true,
        );
        final restored = await _restoreActiveSession(settings);
        if (restored) return;
      }
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

  Future<bool> _restoreActiveSession(UserSettings settings) async {
    if (_recovering) return state.isActive;
    _recovering = true;
    _ticker?.cancel();
    state = state.copyWith(
      status: TimerStatus.syncing,
      clearSession: true,
      clearEndsAt: true,
      clearError: true,
    );

    ActiveFocusSession? activeSession;
    try {
      activeSession = await ref
          .read(focusSessionRemoteDataSourceProvider)
          .getActive();
    } on Object catch (error) {
      state = state.copyWith(
        status: TimerStatus.idle,
        errorMessage: 'Açık oturum kontrol edilemedi. ${_message(error)}',
      );
      _recovering = false;
      return false;
    }

    if (activeSession == null) {
      final seconds = _durationFor(state.phase, settings);
      state = state.copyWith(
        status: TimerStatus.idle,
        plannedSeconds: seconds,
        remainingSeconds: seconds,
        clearSession: true,
        clearEndsAt: true,
        clearError: true,
      );
      _recovering = false;
      return false;
    }

    final remaining = activeSession.remainingSecondsAt(DateTime.now().toUtc());
    state = state.copyWith(
      phase: activeSession.phase,
      status: remaining == 0 ? TimerStatus.paused : TimerStatus.running,
      plannedSeconds: activeSession.plannedSeconds,
      remainingSeconds: remaining,
      sessionId: activeSession.id,
      startedAt: activeSession.startedAt,
      selectedTaskId: activeSession.taskId,
      clearSelectedTask: activeSession.taskId == null,
      endsAt: remaining == 0
          ? null
          : DateTime.now().add(Duration(seconds: remaining)),
      clearEndsAt: remaining == 0,
      clearError: true,
    );
    _recovering = false;

    if (remaining == 0) {
      await _finish(settings);
    } else {
      _startTicker(settings);
    }
    return true;
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
    final cancelledPhase = state.phase;
    state = state.copyWith(status: TimerStatus.cancelling);
    try {
      await ref
          .read(focusSessionRemoteDataSourceProvider)
          .cancel(sessionId, actual.clamp(0, state.plannedSeconds));
      if (cancelledPhase == PomodoroPhase.focus) {
        _resetCurrentPhase(settings);
      } else {
        _setIdlePhase(PomodoroPhase.focus, settings);
      }
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
          ? state.dailyCompletedFocusCount + 1
          : state.dailyCompletedFocusCount;
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
        dailyCompletedFocusCount: focusCount,
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
    _setIdlePhase(state.phase, settings);
  }

  void _setIdlePhase(PomodoroPhase phase, UserSettings settings) {
    final seconds = _durationFor(phase, settings);
    state = state.copyWith(
      phase: phase,
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
