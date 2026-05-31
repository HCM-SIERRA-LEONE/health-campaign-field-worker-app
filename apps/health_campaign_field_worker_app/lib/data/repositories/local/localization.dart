import 'dart:async';
import 'dart:developer' as developer;

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:digit_data_model/utils/utils.dart';
import 'package:drift/drift.dart';

import '../../../utils/utils.dart';
import '../../local_store/no_sql/schema/localization.dart';

class LocalizationLocalRepository {
  static final Map<String, List<Localization>> _queryCache =
      <String, List<Localization>>{};
  static final Map<String, Future<List<Localization>>> _inFlightQueries =
      <String, Future<List<Localization>>>{};
  static int _cacheHitCount = 0;
  static int _cacheMissCount = 0;
  static int _inFlightJoinCount = 0;

  static void clearCache() {
    _queryCache.clear();
    _inFlightQueries.clear();
    developer.log(
      'Localization cache cleared',
      name: 'LocalizationPerf',
    );
  }

  Future<List<Localization>> _getOrLoad(
    String cacheKey,
    Future<List<Localization>> Function() loader,
  ) {
    final cached = _queryCache[cacheKey];
    if (cached != null) {
      _cacheHitCount++;
      developer.log(
        'cache-hit key=$cacheKey size=${cached.length} hit=$_cacheHitCount miss=$_cacheMissCount inflight=$_inFlightJoinCount',
        name: 'LocalizationPerf',
      );
      return Future.value(cached);
    }

    final inFlight = _inFlightQueries[cacheKey];
    if (inFlight != null) {
      _inFlightJoinCount++;
      developer.log(
        'inflight-join key=$cacheKey count=$_inFlightJoinCount',
        name: 'LocalizationPerf',
      );
      return inFlight;
    }
    _cacheMissCount++;

    final stopwatch = Stopwatch()..start();
    final future = loader().then((value) {
      _queryCache[cacheKey] = value;
      stopwatch.stop();
      developer.log(
        'cache-miss key=$cacheKey rows=${value.length} elapsedMs=${stopwatch.elapsedMilliseconds} hit=$_cacheHitCount miss=$_cacheMissCount',
        name: 'LocalizationPerf',
      );
      return value;
    });

    _inFlightQueries[cacheKey] = future;

    return future.whenComplete(() {
      _inFlightQueries.remove(cacheKey);
    });
  }

  String _buildReturnLocalizationCacheKey() {
    final locale = '${LocalizationParams().locale ?? ''}';
    final module = LocalizationParams().module ?? '';
    final exclude = LocalizationParams().exclude ?? true;
    final sortedCodes = [...(LocalizationParams().code ?? const <String>[])]
      ..sort();
    return 'return|$locale|$module|$exclude|${sortedCodes.join(',')}';
  }

  String _buildFetchLocalizationCacheKey({
    required String locale,
    required String module,
  }) {
    final moduleList = _normalizeList(module)..sort();
    return 'fetch|$locale|${moduleList.join(',')}';
  }

  List<String> _normalizeList(String raw) {
    final values = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<List<TypedResult>> _runJoinedQuery(
    LocalSqlDataStore sql, {
    required Expression<bool> predicate,
  }) async {
    final query = sql.select(sql.localization).join([])..where(predicate);
    return query.get();
  }

  List<Localization> _mapRows(
    LocalSqlDataStore sql,
    List<TypedResult> rows,
  ) {
    return rows.map((row) {
      final data = row.readTableOrNull(sql.localization);
      if (data == null) {
        throw StateError('No data found for localization');
      }

      return Localization()
        ..code = data.code
        ..locale = data.locale
        ..module = data.module
        ..message = data.message;
    }).toList();
  }

  List<Localization> _mergeLocalizations(
    List<Localization> first,
    List<Localization> second,
  ) {
    final merged = <String, Localization>{};
    for (final item in [...first, ...second]) {
      final key = '${item.locale}|${item.code}|${item.module}';
      merged[key] = item;
    }
    return merged.values.toList();
  }

  FutureOr<List<Localization>> returnLocalizationFromSQL(
      LocalSqlDataStore sql) async {
    final cacheKey = _buildReturnLocalizationCacheKey();

    return _getOrLoad(cacheKey, () {
      return retryLocalCallOperation(() async {
        final locale = LocalizationParams().locale;
        if (locale == null) return <Localization>[];

        final localeString = '$locale';
        final moduleRaw = LocalizationParams().module ?? '';
        final moduleList = _normalizeList(moduleRaw);
        final codes = [...(LocalizationParams().code ?? const <String>[])]
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final exclude = LocalizationParams().exclude ?? true;

        if (moduleList.isNotEmpty) {
          if (exclude) {
            // Query-shaping: avoid broad OR by splitting module/code reads.
            final excludedRows = await _runJoinedQuery(
              sql,
              predicate: buildAnd([
                sql.localization.locale.equals(localeString),
                sql.localization.module.isIn(moduleList).not(),
              ]),
            );
            final excludedResults = _mapRows(sql, excludedRows);
            if (codes.isEmpty) return excludedResults;

            final codeRows = await _runJoinedQuery(
              sql,
              predicate: buildAnd([
                sql.localization.locale.equals(localeString),
                sql.localization.code.isIn(codes),
              ]),
            );
            return _mergeLocalizations(excludedResults, _mapRows(sql, codeRows));
          } else {
            // Query-shaping: fetch module rows first, then only missing code rows.
            final moduleRows = await _runJoinedQuery(
              sql,
              predicate: buildAnd([
                sql.localization.locale.equals(localeString),
                sql.localization.module.isIn(moduleList),
              ]),
            );
            final moduleResults = _mapRows(sql, moduleRows);
            if (codes.isEmpty) return moduleResults;

            final existingCodes = moduleResults
                .map((e) => e.code)
                .whereType<String>()
                .toSet();
            final missingCodes =
                codes.where((code) => !existingCodes.contains(code)).toList();
            if (missingCodes.isEmpty) return moduleResults;

            final codeRows = await _runJoinedQuery(
              sql,
              predicate: buildAnd([
                sql.localization.locale.equals(localeString),
                sql.localization.code.isIn(missingCodes),
              ]),
            );
            return _mergeLocalizations(moduleResults, _mapRows(sql, codeRows));
          }
        }

        if (codes.isNotEmpty) {
          final codeRows = await _runJoinedQuery(
            sql,
            predicate: buildAnd([
              sql.localization.locale.equals(localeString),
              sql.localization.code.isIn(codes),
            ]),
          );
          return _mapRows(sql, codeRows);
        }

        final localeRows = await _runJoinedQuery(
          sql,
          predicate: sql.localization.locale.equals(localeString),
        );
        return _mapRows(sql, localeRows);
      });
    });
  }

  FutureOr<List<Localization>> fetchLocalization(
      {required LocalSqlDataStore sql,
      required String locale,
      required String module}) async {
    final cacheKey =
        _buildFetchLocalizationCacheKey(locale: locale, module: module);

    return _getOrLoad(cacheKey, () {
      return retryLocalCallOperation(() async {
        final moduleList = _normalizeList(module);
        if (moduleList.isEmpty) return <Localization>[];

        final query = sql.select(sql.localization).join([])
          ..where(
            buildAnd([
              sql.localization.locale.equals(locale),
              sql.localization.module.isIn(moduleList),
            ]),
          );

        final results = await query.get();

        return results.map((e) {
          final data = e.readTableOrNull(sql.localization);

          if (data == null) {
            throw StateError('No data found for localization');
          }

          return Localization()
            ..code = data.code
            ..locale = data.locale
            ..module = data.module
            ..message = data.message;
        }).toList();
      });
    });
  }

  FutureOr create(
      List<LocalizationCompanion> result, LocalSqlDataStore sql) async {
    if (result.isEmpty) return;
    return retryLocalCallOperation(() async {
      final response = await sql.batch((batch) {
        batch.insertAllOnConflictUpdate(sql.localization, result);
      });
      clearCache();
      developer.log(
        'cache-invalidate-on-create inserted=${result.length}',
        name: 'LocalizationPerf',
      );
      return response;
    });
  }
}