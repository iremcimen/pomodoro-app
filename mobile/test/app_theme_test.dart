import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_app/app/theme/app_colors.dart';
import 'package:pomodoro_app/app/theme/app_theme.dart';

void main() {
  test('light theme uses the Cyber Grape and Acid Lime brand roles', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.cyberGrape);
    expect(theme.colorScheme.secondary, AppColors.acidLime);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppColors.acidLime,
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppColors.cyberGrapeDark,
    );
  });

  test('brand foreground pairs meet the text contrast floor', () {
    final secondaryText = Color.alphaBlend(
      AppColors.acidLime.withValues(alpha: 0.86),
      AppColors.cyberGrape,
    );

    expect(
      _contrastRatio(AppColors.acidLime, AppColors.cyberGrapeDark),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(Colors.white, AppColors.cyberGrape),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(secondaryText, AppColors.cyberGrape),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('dark theme keeps Acid Lime as the action accent', () {
    final theme = AppTheme.dark;

    expect(theme.colorScheme.secondary, AppColors.acidLime);
    expect(theme.scaffoldBackgroundColor, AppColors.darkCanvas);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}
