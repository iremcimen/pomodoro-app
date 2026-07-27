import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/active_focus_session.dart';
import '../domain/pomodoro_state.dart';

class FocusSessionRemoteDataSource {
  const FocusSessionRemoteDataSource(this._dio);
  final Dio _dio;

  Future<ActiveFocusSession?> getActive() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/focus-sessions/active',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Missing active focus session response.');
      }
      return ActiveFocusSession.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw AppException.fromDio(error);
    } on FormatException {
      throw const AppException(
        message: 'Açık oturum bilgisi okunamadı. Lütfen tekrar deneyin.',
        code: 'INVALID_FOCUS_SESSION_RESPONSE',
      );
    }
  }

  Future<void> start({
    required String id,
    required PomodoroPhase phase,
    required int plannedSeconds,
    required DateTime startedAt,
    int? taskId,
  }) async {
    await _request(
      () => _dio.post<void>(
        '/focus-sessions',
        data: {
          'id': id,
          'task_id': phase == PomodoroPhase.focus ? taskId : null,
          'session_type': _phaseName(phase),
          'planned_duration_seconds': plannedSeconds,
          'started_at': startedAt.toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<void> complete(String id, int actualSeconds) =>
      _end(id: id, action: 'complete', actualSeconds: actualSeconds);

  Future<void> cancel(String id, int actualSeconds) =>
      _end(id: id, action: 'cancel', actualSeconds: actualSeconds);

  Future<void> _end({
    required String id,
    required String action,
    required int actualSeconds,
  }) => _request(
    () => _dio.post<void>(
      '/focus-sessions/$id/$action',
      data: {'actual_duration_seconds': actualSeconds},
    ),
  );

  Future<void> _request(Future<Response<dynamic>> Function() request) async {
    try {
      await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  String _phaseName(PomodoroPhase phase) => switch (phase) {
    PomodoroPhase.focus => 'focus',
    PomodoroPhase.shortBreak => 'short_break',
    PomodoroPhase.longBreak => 'long_break',
  };
}
