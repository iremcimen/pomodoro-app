import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.fast),
        reverseDuration: AppMotion.resolve(
          context,
          const Duration(milliseconds: 120),
        ),
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        child: isLoading
            ? Semantics(
                key: const ValueKey('loading'),
                label: loadingLabel,
                liveRegion: true,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (disableAnimations)
                        const Icon(Icons.hourglass_top_rounded, size: 20)
                      else
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          loadingLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}
