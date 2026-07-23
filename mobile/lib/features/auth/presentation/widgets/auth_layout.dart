import 'package:flutter/material.dart';

import 'app_logo.dart';
import 'auth_brand_panel.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  static const _desktopBreakpoint = 920.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _desktopBreakpoint) {
              return Row(
                children: [
                  const Expanded(flex: 9, child: AuthBrandPanel()),
                  Expanded(
                    flex: 11,
                    child: _ScrollableForm(
                      title: title,
                      subtitle: subtitle,
                      form: form,
                      footer: footer,
                      showLogo: false,
                    ),
                  ),
                ],
              );
            }

            return _ScrollableForm(
              title: title,
              subtitle: subtitle,
              form: form,
              footer: footer,
              showLogo: true,
            );
          },
        ),
      ),
    );
  }
}

class _ScrollableForm extends StatelessWidget {
  const _ScrollableForm({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    required this.showLogo,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 480 ? 24.0 : 48.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showLogo) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: AppLogo(compact: true),
                      ),
                      const SizedBox(height: 48),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    form,
                    const SizedBox(height: 28),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
