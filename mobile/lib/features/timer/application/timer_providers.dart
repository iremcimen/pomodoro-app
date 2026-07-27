import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/focus_session_remote_data_source.dart';

final focusSessionRemoteDataSourceProvider =
    Provider<FocusSessionRemoteDataSource>((ref) {
      return FocusSessionRemoteDataSource(ref.watch(dioProvider));
    });
