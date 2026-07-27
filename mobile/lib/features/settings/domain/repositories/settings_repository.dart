import '../entities/user_settings.dart';

abstract interface class SettingsRepository {
  Future<UserSettings> fetch();
  Future<UserSettings> update(UserSettings settings);
}
