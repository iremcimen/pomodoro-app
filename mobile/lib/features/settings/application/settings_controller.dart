import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/user_settings.dart';
import 'settings_providers.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UserSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() => ref.read(settingsRepositoryProvider).fetch();

  Future<bool> save(UserSettings settings) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(settingsRepositoryProvider).update(settings),
    );
    return !state.hasError;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(settingsRepositoryProvider).fetch(),
    );
  }
}
