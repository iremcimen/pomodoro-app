import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._remoteDataSource);
  final SettingsRemoteDataSource _remoteDataSource;

  @override
  Future<UserSettings> fetch() => _remoteDataSource.fetch();

  @override
  Future<UserSettings> update(UserSettings settings) =>
      _remoteDataSource.update(settings);
}
