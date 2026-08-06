import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/features/auth/presentation/widgets/auth_layout.dart';
import 'package:pomodoro_app/features/auth/presentation/widgets/submit_button.dart';

void main() {
  testWidgets('auth layout shows mobile content on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthLayout(
          title: 'Tekrar hoş geldin',
          subtitle: 'Odağına geri dön.',
          form: Text('Form içeriği'),
          footer: Text('Alt bağlantı'),
        ),
      ),
    );

    expect(find.text('pomo'), findsOneWidget);
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(find.text('Form içeriği'), findsOneWidget);
  });

  testWidgets('auth layout shows brand panel on a wide viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthLayout(
          title: 'Hesabını oluştur',
          subtitle: 'İlk adımını at.',
          form: Text('Form içeriği'),
          footer: Text('Alt bağlantı'),
        ),
      ),
    );

    expect(find.textContaining('Zamanını geri al'), findsOneWidget);
    expect(find.text('Hesabını oluştur'), findsOneWidget);
  });

  testWidgets('yükleme durumu azaltılmış harekette statik olarak anlaşılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: SubmitButton(
                label: 'Giriş yap',
                loadingLabel: 'Giriş yapılıyor…',
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Giriş yapılıyor…'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
