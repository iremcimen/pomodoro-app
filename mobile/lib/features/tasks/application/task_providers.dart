import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/entities/task_item.dart';

final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>((ref) {
  return TaskRemoteDataSource(ref.watch(dioProvider));
});

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, List<TaskItem>>(TaskController.new);

final activeTasksProvider = Provider<AsyncValue<List<TaskItem>>>((ref) {
  return ref
      .watch(taskControllerProvider)
      .whenData((tasks) => tasks.where((task) => !task.isCompleted).toList());
});

class TaskController extends AsyncNotifier<List<TaskItem>> {
  @override
  Future<List<TaskItem>> build() =>
      ref.read(taskRemoteDataSourceProvider).list();

  Future<bool> create({
    required String title,
    required String? description,
    required int estimatedPomodoros,
  }) => _mutate(
    () => ref
        .read(taskRemoteDataSourceProvider)
        .create(
          title: title,
          description: description,
          estimatedPomodoros: estimatedPomodoros,
        ),
  );

  Future<bool> edit({
    required int id,
    String? title,
    String? description,
    int? estimatedPomodoros,
    bool? isCompleted,
  }) => _mutate(
    () => ref
        .read(taskRemoteDataSourceProvider)
        .update(
          id: id,
          title: title,
          description: description,
          estimatedPomodoros: estimatedPomodoros,
          isCompleted: isCompleted,
        ),
  );

  Future<bool> delete(int id) async {
    try {
      await ref.read(taskRemoteDataSourceProvider).delete(id);
      state = AsyncData(
        (state.value ?? const []).where((task) => task.id != id).toList(),
      );
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRemoteDataSourceProvider).list(),
    );
  }

  Future<bool> _mutate(Future<TaskItem> Function() request) async {
    try {
      final updated = await request();
      final tasks = [...state.value ?? const <TaskItem>[]];
      final index = tasks.indexWhere((task) => task.id == updated.id);
      if (index == -1) {
        tasks.insert(0, updated);
      } else {
        tasks[index] = updated;
      }
      state = AsyncData(tasks);
      return true;
    } on Object {
      return false;
    }
  }
}

class TaskRemoteDataSource {
  const TaskRemoteDataSource(this._dio);
  final Dio _dio;

  Future<List<TaskItem>> list() async {
    final response = await _request(
      () => _dio.get<List<dynamic>>('/tasks', queryParameters: {'limit': 100}),
    );
    final data = response.data;
    if (data is! List) throw _invalidResponse;
    try {
      return data
          .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on Object {
      throw _invalidResponse;
    }
  }

  Future<TaskItem> create({
    required String title,
    required String? description,
    required int estimatedPomodoros,
  }) => _write(
    () => _dio.post<Map<String, dynamic>>(
      '/tasks',
      data: {
        'title': title.trim(),
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'estimated_pomodoros': estimatedPomodoros,
      },
    ),
  );

  Future<TaskItem> update({
    required int id,
    String? title,
    String? description,
    int? estimatedPomodoros,
    bool? isCompleted,
  }) {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (description != null) {
      data['description'] = description.trim().isEmpty
          ? null
          : description.trim();
    }
    if (estimatedPomodoros != null) {
      data['estimated_pomodoros'] = estimatedPomodoros;
    }
    if (isCompleted != null) data['is_completed'] = isCompleted;
    return _write(
      () => _dio.patch<Map<String, dynamic>>('/tasks/$id', data: data),
    );
  }

  Future<void> delete(int id) async {
    await _request(() => _dio.delete<void>('/tasks/$id'));
  }

  Future<TaskItem> _write(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    final data = (await _request(request)).data;
    if (data == null) throw _invalidResponse;
    try {
      return TaskItem.fromJson(data);
    } on Object {
      throw _invalidResponse;
    }
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  AppException get _invalidResponse => const AppException(
    message: 'Sunucudan geçersiz bir görev yanıtı alındı.',
    code: 'INVALID_RESPONSE',
  );
}
