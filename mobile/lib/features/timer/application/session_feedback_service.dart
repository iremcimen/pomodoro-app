import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/entities/user_settings.dart';

final sessionFeedbackServiceProvider = Provider<SessionFeedbackService>(
  (_) => const SessionFeedbackService(),
);

class SessionFeedbackService {
  const SessionFeedbackService();

  Future<void> sessionCompleted(UserSettings settings) async {
    try {
      if (settings.soundEnabled) {
        await SystemSound.play(SystemSoundType.alert);
      }
      if (settings.vibrationEnabled) {
        await HapticFeedback.mediumImpact();
      }
    } on Object {
      // Device feedback is best effort and must never fail session storage.
    }
  }
}
