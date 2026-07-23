import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../application/auth_controller.dart';
import '../../domain/entities/auth_session.dart';

void listenForAuthErrors(WidgetRef ref, BuildContext context) {
  ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (
    previous,
    next,
  ) {
    if (!next.hasError || identical(previous?.error, next.error)) return;

    final error = next.error;
    final message = error is AppException
        ? error.message
        : 'Beklenmeyen bir sorun oluştu. Lütfen tekrar deneyin.';

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
  });
}
