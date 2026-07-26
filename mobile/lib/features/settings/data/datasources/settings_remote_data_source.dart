import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/user_settings.dart';
import '../models/user_settings_dto.dart';

abstract interface class SettingsRemoteDataSource {
  Future<UserSettings> fetch();
  Future<UserSettings> update(UserSettings settings);
}

class DioSettingsRemoteDataSource implements SettingsRemoteDataSource {
  const DioSettingsRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<UserSettings> fetch() => _request(() => _dio.get('/settings/me'));

  @override
  Future<UserSettings> update(UserSettings settings) => _request(
    () =>
        _dio.patch('/settings/me', data: UserSettingsDto.toPatchJson(settings)),
  );

  Future<UserSettings> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final data = (await request()).data;
      if (data is! Map<String, dynamic>) throw const FormatException();
      return UserSettingsDto.fromJson(data);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on FormatException {
      throw const AppException(
        message: 'Sunucudan geçersiz bir ayar yanıtı alındı.',
        code: 'INVALID_RESPONSE',
      );
    }
  }
}
