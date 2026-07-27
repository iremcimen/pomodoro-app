import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/statistics_summary.dart';

final statisticsControllerProvider =
    AsyncNotifierProvider<StatisticsController, StatisticsSummary>(
      StatisticsController.new,
    );

class StatisticsController extends AsyncNotifier<StatisticsSummary> {
  static const _cacheKey = 'cache.statistics.summary';

  @override
  Future<StatisticsSummary> build() => _fetchWithFallback();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchWithFallback);
  }

  Future<StatisticsSummary> _fetchWithFallback() async {
    try {
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      final response = await ref
          .read(dioProvider)
          .get<Map<String, dynamic>>(
            '/statistics/summary',
            queryParameters: {'timezone_offset_minutes': offset},
          );
      final data = response.data;
      if (data == null) throw const FormatException();
      final summary = StatisticsSummary.fromJson(data);
      await _writeCache(summary);
      return summary;
    } on DioException catch (error) {
      final cached = await _readCache();
      if (cached != null) return cached;
      throw AppException.fromDio(error);
    } on FormatException {
      final cached = await _readCache();
      if (cached != null) return cached;
      throw const AppException(
        message: 'İstatistik verisi okunamadı.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  Future<StatisticsSummary?> _readCache() async {
    try {
      final value = await ref.read(secureStorageProvider).read(key: _cacheKey);
      if (value == null) return null;
      return StatisticsSummary.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
        isOffline: true,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeCache(StatisticsSummary summary) async {
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: _cacheKey, value: jsonEncode(summary.toJson()));
    } on Object {
      // Cache is best effort; fresh network data remains usable.
    }
  }
}
