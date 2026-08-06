import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import '../../../../app/theme/app_tokens.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.isLoading,
    required this.isEnabled,
    VoidCallback? onPressed,
    super.key,
  }) : assert(onPressed == null, 'Web Google button handles its own clicks.');

  final bool isLoading;
  final bool isEnabled;
  static const maxWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    final disabled = !isEnabled || isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = constraints.maxWidth.clamp(240.0, maxWidth);

        return Semantics(
          label: isLoading ? 'Google ile giriş yapılıyor' : null,
          liveRegion: isLoading,
          child: AbsorbPointer(
            absorbing: disabled,
            child: AnimatedOpacity(
              opacity: disabled ? 0.58 : 1,
              duration: AppMotion.resolve(context, AppMotion.fast),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: web.renderButton(
                    configuration: web.GSIButtonConfiguration(
                      type: web.GSIButtonType.standard,
                      theme: isDark
                          ? web.GSIButtonTheme.filledBlack
                          : web.GSIButtonTheme.outline,
                      size: web.GSIButtonSize.large,
                      text: web.GSIButtonText.continueWith,
                      shape: web.GSIButtonShape.pill,
                      logoAlignment: web.GSIButtonLogoAlignment.left,
                      minimumWidth: buttonWidth,
                      locale: 'tr',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
