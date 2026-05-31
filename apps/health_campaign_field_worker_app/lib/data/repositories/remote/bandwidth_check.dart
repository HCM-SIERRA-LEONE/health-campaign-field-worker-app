import 'dart:async';

import 'package:dio/dio.dart';

import '../../../utils/environment_config.dart';

class BandwidthCheckRepository {
  final Dio _client;
  final String bandwidthPath;
  static final Map<String, double> _cachedSpeeds = <String, double>{};
  static final Map<String, DateTime> _cacheTimes = <String, DateTime>{};
  static final Map<String, Future<double>> _inFlightChecks =
      <String, Future<double>>{};
  static const Duration _cacheTtl = Duration(seconds: 20);

  const BandwidthCheckRepository(this._client, {required this.bandwidthPath});

  FutureOr pingBandwidthCheck({
    required bandWidthCheckModel,
  }) async {
    final cacheKey = '$bandwidthPath|${envConfig.variables.tenantId}';
    final now = DateTime.now();
    final cached = _cachedSpeeds[cacheKey];
    final cachedAt = _cacheTimes[cacheKey];
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) <= _cacheTtl) {
      return cached;
    }

    final inFlight = _inFlightChecks[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final payload = bandWidthCheckModel is Map<String, dynamic>
        ? bandWidthCheckModel
        : <String, dynamic>{};

    final future = _measureBandwidth(payload).then((speed) {
      _cachedSpeeds[cacheKey] = speed;
      _cacheTimes[cacheKey] = DateTime.now();
      return speed;
    }).whenComplete(() {
      _inFlightChecks.remove(cacheKey);
    });

    _inFlightChecks[cacheKey] = future;
    return future;
  }

  Future<double> _measureBandwidth(Map<String, dynamic> payload) async {
    final headers = <String, String>{};
    final startTime = DateTime.now();
    await _client.post(
      bandwidthPath,
      data: payload,
      queryParameters: {"tenantId": envConfig.variables.tenantId},
      options: Options(headers: headers),
    );

    final elapsedSeconds =
        (DateTime.now().difference(startTime).inMilliseconds) / 1000;
    final safeSeconds = elapsedSeconds <= 0 ? 0.001 : elapsedSeconds;
    return ((800 / safeSeconds) / 1000);
  }
}
