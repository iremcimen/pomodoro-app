import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.onDark = false, this.compact = false});

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? AppColors.acidLime : AppColors.cyberGrape;

    return Semantics(
      label: 'Pomo',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            decoration: BoxDecoration(
              color: onDark ? AppColors.acidLime : AppColors.cyberGrape,
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.timer_rounded,
              color: onDark ? AppColors.cyberGrape : AppColors.acidLime,
              size: compact ? 23 : 27,
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Text(
              'pomo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
