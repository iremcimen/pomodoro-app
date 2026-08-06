import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'app_logo.dart';

class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cyberGrape,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            right: -150,
            top: -110,
            child: _DecorativeCircle(size: 390, opacity: 0.08),
          ),
          const Positioned(
            left: -130,
            bottom: -170,
            child: _DecorativeCircle(size: 430, opacity: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 46, 56, 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(onDark: true),
                const Spacer(),
                Text(
                  'Zamanını geri al.\nOdağını koru.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Net çalışma aralıkları, bilinçli molalar ve daha sakin bir gün.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.acidLime.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 38),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FeaturePill(icon: Icons.bolt_rounded, label: 'Derin odak'),
                    _FeaturePill(
                      icon: Icons.insights_rounded,
                      label: 'Görünür ilerleme',
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Küçük adımlar. Büyük ilerleme.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.acidLime.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.acidLime.withValues(alpha: opacity),
          width: 70,
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.acidLime,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.cyberGrapeDark),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cyberGrapeDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
