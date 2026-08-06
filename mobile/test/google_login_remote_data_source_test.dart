import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  test('Google ID token is sent only to the backend Google endpoint', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);

    final dataSource = DioAuthRemoteDataSource(dio);
    final result = await dataSource.loginWithGoogle('  google-id-token  ');

    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.uri.path, '/api/v1/auth/google');
    expect(adapter.request?.data, {'id_token': 'google-id-token'});
    expect(result.accessToken, 'access-token');
    expect(result.refreshToken, 'refresh-token');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
        'token_type': 'bearer',
        'expires_in': 900,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
