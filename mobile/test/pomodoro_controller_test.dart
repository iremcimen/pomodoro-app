import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/core/error/app_exception.dart';
import 'package:pomodoro_app/features/settings/domain/entities/user_settings.dart';
import 'package:pomodoro_app/features/timer/application/pomodoro_controller.dart';
import 'package:pomodoro_app/features/timer/application/timer_providers.dart';
import 'package:pomodoro_app/features/timer/data/focus_session_remote_data_source.dart';
import 'package:pomodoro_app/features/timer/domain/active_focus_session.dart';
import 'package:pomodoro_app/features/timer/domain/pomodoro_state.dart';

void main() {
  test('günlük odak sayısını sunucu değeriyle senkronlar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(pomodoroControllerProvider.notifier);
    controller.syncDailyCompletedFocusCount(3);

    expect(
      container.read(pomodoroControllerProvider).dailyCompletedFocusCount,
      3,
    );

    controller.syncDailyCompletedFocusCount(0);

    expect(
      container.read(pomodoroControllerProvider).dailyCompletedFocusCount,
      0,
      reason: 'Yeni günde sunucudaki sıfır değeri yerel sayacı sıfırlamalı.',
    );
  });

  test('geçersiz negatif günlük odak sayısını yok sayar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(pomodoroControllerProvider.notifier);
    controller.syncDailyCompletedFocusCount(-1);

    expect(
      container.read(pomodoroControllerProvider).dailyCompletedFocusCount,
      0,
    );
  });

  test('boştayken aşama seçer ve molayı odağa atlar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(pomodoroControllerProvider.notifier);
    final settings = UserSettings.defaults.copyWith(shortBreakMinutes: 7);

    controller.selectPhase(PomodoroPhase.shortBreak, settings);

    expect(
      container.read(pomodoroControllerProvider),
      isA<PomodoroState>()
          .having((state) => state.phase, 'phase', PomodoroPhase.shortBreak)
          .having((state) => state.remainingSeconds, 'remainingSeconds', 420),
    );

    controller.skipBreak(settings);

    expect(
      container.read(pomodoroControllerProvider),
      isA<PomodoroState>()
          .having((state) => state.phase, 'phase', PomodoroPhase.focus)
          .having((state) => state.status, 'status', TimerStatus.idle),
    );
  });

  test('uygulama açılınca sunucudaki aktif oturumu geri yükler', () async {
    final remote = _FakeFocusSessionRemoteDataSource(
      activeSession: ActiveFocusSession(
        id: 'active-session',
        phase: PomodoroPhase.focus,
        plannedSeconds: 60,
        startedAt: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
        taskId: 7,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(pomodoroControllerProvider.notifier)
        .initialize(UserSettings.defaults);

    final state = container.read(pomodoroControllerProvider);
    expect(remote.getActiveCalls, 1);
    expect(state.status, TimerStatus.running);
    expect(state.sessionId, 'active-session');
    expect(state.selectedTaskId, 7);
    expect(state.remainingSeconds, inInclusiveRange(49, 50));
  });

  test('başlatma çakışırsa mevcut aktif oturumu geri yükler', () async {
    final remote = _FakeFocusSessionRemoteDataSource();
    final container = ProviderContainer(
      overrides: [
        focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(pomodoroControllerProvider.notifier);

    await controller.initialize(UserSettings.defaults);
    remote
      ..activeSession = ActiveFocusSession(
        id: 'server-session',
        phase: PomodoroPhase.shortBreak,
        plannedSeconds: 300,
        startedAt: DateTime.now().toUtc(),
      )
      ..startError = const AppException(
        message: 'Active session exists.',
        code: 'ACTIVE_SESSION_EXISTS',
        statusCode: 409,
      );

    await controller.start(UserSettings.defaults);

    final state = container.read(pomodoroControllerProvider);
    expect(remote.startCalls, 1);
    expect(remote.getActiveCalls, 2);
    expect(state.status, TimerStatus.running);
    expect(state.phase, PomodoroPhase.shortBreak);
    expect(state.sessionId, 'server-session');
  });

  test('başlatma yanıtını beklerken başlangıç durumunu gösterir', () async {
    final remote = _FakeFocusSessionRemoteDataSource(
      startGate: Completer<void>(),
    );
    final container = ProviderContainer(
      overrides: [
        focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(pomodoroControllerProvider.notifier);

    await controller.initialize(UserSettings.defaults);
    final start = controller.start(UserSettings.defaults);

    expect(
      container.read(pomodoroControllerProvider).status,
      TimerStatus.starting,
    );

    remote.startGate!.complete();
    await start;

    expect(
      container.read(pomodoroControllerProvider).status,
      TimerStatus.running,
    );
  });

  test(
    'süresi geçmiş aktif oturumu tamamlayıp sonraki aşamaya geçer',
    () async {
      final remote = _FakeFocusSessionRemoteDataSource(
        activeSession: ActiveFocusSession(
          id: 'expired-session',
          phase: PomodoroPhase.focus,
          plannedSeconds: 60,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 61),
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);
      final settings = UserSettings.defaults.copyWith(
        focusDurationMinutes: 1,
        shortBreakMinutes: 1,
        soundEnabled: false,
        vibrationEnabled: false,
      );

      await container
          .read(pomodoroControllerProvider.notifier)
          .initialize(settings);

      final state = container.read(pomodoroControllerProvider);
      expect(remote.completedSessionIds, ['expired-session']);
      expect(state.status, TimerStatus.idle);
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.dailyCompletedFocusCount, 1);
    },
  );

  test('çalışan molayı iptal edince odağı hazırlar', () async {
    final remote = _FakeFocusSessionRemoteDataSource();
    final container = ProviderContainer(
      overrides: [
        focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(pomodoroControllerProvider.notifier);
    final settings = UserSettings.defaults.copyWith(shortBreakMinutes: 7);

    await controller.initialize(settings);
    controller.selectPhase(PomodoroPhase.shortBreak, settings);
    await controller.start(settings);
    await controller.cancel(settings);

    final state = container.read(pomodoroControllerProvider);
    expect(remote.cancelledSessionIds, hasLength(1));
    expect(state.phase, PomodoroPhase.focus);
    expect(state.status, TimerStatus.idle);
    expect(state.remainingSeconds, settings.focusDurationMinutes * 60);
  });

  test('iptal yanıtını beklerken iptal durumunu gösterir', () async {
    final remote = _FakeFocusSessionRemoteDataSource(
      cancelGate: Completer<void>(),
    );
    final container = ProviderContainer(
      overrides: [
        focusSessionRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(pomodoroControllerProvider.notifier);

    await controller.initialize(UserSettings.defaults);
    await controller.start(UserSettings.defaults);
    final cancel = controller.cancel(UserSettings.defaults);

    expect(
      container.read(pomodoroControllerProvider).status,
      TimerStatus.cancelling,
    );

    remote.cancelGate!.complete();
    await cancel;

    expect(
      container.read(pomodoroControllerProvider).status,
      TimerStatus.idle,
    );
  });
}

class _FakeFocusSessionRemoteDataSource extends FocusSessionRemoteDataSource {
  _FakeFocusSessionRemoteDataSource({
    this.activeSession,
    this.startGate,
    this.cancelGate,
  }) : super(Dio());

  ActiveFocusSession? activeSession;
  Completer<void>? startGate;
  Completer<void>? cancelGate;
  Object? startError;
  int getActiveCalls = 0;
  int startCalls = 0;
  final List<String> completedSessionIds = [];
  final List<String> cancelledSessionIds = [];

  @override
  Future<ActiveFocusSession?> getActive() async {
    getActiveCalls += 1;
    return activeSession;
  }

  @override
  Future<void> start({
    required String id,
    required PomodoroPhase phase,
    required int plannedSeconds,
    required DateTime startedAt,
    int? taskId,
  }) async {
    startCalls += 1;
    if (startError case final error?) throw error;
    await startGate?.future;
  }

  @override
  Future<void> complete(String id, int actualSeconds) async {
    completedSessionIds.add(id);
  }

  @override
  Future<void> cancel(String id, int actualSeconds) async {
    await cancelGate?.future;
    cancelledSessionIds.add(id);
  }
}
