// Generated using mason. Do not modify by hand

import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';

import '../../../models/downsync/downsync.dart';

class DownsyncRemoteRepository
    extends RemoteRepository<DownsyncModel, DownsyncSearchModel> {
  DownsyncRemoteRepository(
    super.dio, {
    required super.actionMap,
    super.entityName = 'Downsync',
  });

  @override
  DataModelType get type => DataModelType.downsync;

  /// Builds the downsync URL with the Osun-specific base host
  /// (`bauchi-hcm` -> `osun-hcm`). Returns an absolute URL so dio bypasses
  /// its configured baseUrl for just this call.
  String _resolveOsunDownsyncUrl() {
    final path = searchPath;
    final isAbsolute =
        path.startsWith('http://') || path.startsWith('https://');
    if (isAbsolute) {
      return path.replaceFirst('bauchi-hcm', 'osun-hcm');
    }

    final rewrittenBase =
        dio.options.baseUrl.replaceFirst('bauchi-hcm', 'osun-hcm');
    final baseNoTrailing = rewrittenBase.endsWith('/')
        ? rewrittenBase.substring(0, rewrittenBase.length - 1)
        : rewrittenBase;
    final pathWithLeading = path.startsWith('/') ? path : '/$path';
    return '$baseNoTrailing$pathWithLeading';
  }

  @override
  FutureOr<Map<String, dynamic>> downSync(
    DownsyncSearchModel query, {
    int? offSet,
    int? limit,
  }) async {
    Response response;
    final url = _resolveOsunDownsyncUrl();

    try {
      response = await executeFuture(
        future: () async {
          return await dio.post(
            url,
            queryParameters: {
              'offset': offSet ?? 0,
              'limit': limit ?? 100,
              'tenantId': DigitDataModelSingleton().tenantId,
              if (query.isDeleted ?? false) 'includeDeleted': query.isDeleted,
            },
            data: {
              'DownsyncCriteria': query.toMap(),
            },
          );
        },
      );
    } catch (error) {
      return {};
    }

    final responseMap = response.data;

    // ignore: avoid_dynamic_calls
    if (!responseMap.containsKey(entityName)) {
      throw InvalidApiResponseException(
        data: query.toMap(),
        path: url,
        response: responseMap,
      );
    }

    // ignore: avoid_dynamic_calls
    return responseMap[entityName];
  }
}
