import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/datasources/settings_remote_data_source.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';

final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>((
  ref,
) {
  return DioSettingsRemoteDataSource(ref.watch(dioProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(settingsRemoteDataSourceProvider));
});
