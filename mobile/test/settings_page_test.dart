import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/settings/application/settings_providers.dart';
import 'package:pomodoro_app/features/settings/domain/entities/user_settings.dart';
import 'package:pomodoro_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:pomodoro_app/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('zamanlayıcı değeri klavyeyle girilip kaydedilebilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSettingsRepository();
    await tester.pumpWidget(_settingsApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('setting-focus-duration')),
      '20',
    );
    final saveButton = find.byKey(const Key('settings-save-button'));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.updated?.focusDurationMinutes, 20);
  });

  testWidgets('sınır dışı giriş izin verilen en yüksek değere çekilir', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository();
    await tester.pumpWidget(_settingsApp(repository));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('setting-long-break-interval'));
    await tester.enterText(field, '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final textField = tester.widget<TextField>(field);
    expect(textField.controller?.text, '12');
  });
}

Widget _settingsApp(_FakeSettingsRepository repository) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: Scaffold(body: SettingsPage())),
  );
}

class _FakeSettingsRepository implements SettingsRepository {
  UserSettings? updated;

  @override
  Future<UserSettings> fetch() async => UserSettings.defaults;

  @override
  Future<UserSettings> update(UserSettings settings) async {
    updated = settings;
    return settings;
  }
}
