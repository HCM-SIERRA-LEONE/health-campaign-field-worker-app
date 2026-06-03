import 'dart:async';

import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:digit_data_model/utils/utils.dart';
import 'package:drift/drift.dart';

import '../../../utils/utils.dart';
import '../../local_store/no_sql/schema/localization.dart';
class LocalizationLocalRepository {
  Future<List<Localization>> returnLocalizationFromSQL(
      LocalSqlDataStore sql) {
    return LocalizationSqlCache.instance.load(sql);
  }

  Future<List<Localization>> returnLocalizationFromSQLUncached(
      LocalSqlDataStore sql) async {
    return retryLocalCallOperation(() async {
      final selectQuery = sql.select(sql.localization).join([]);

      // List to hold the AND conditions
      final andConditions = <Expression<bool>>[];

      // Add condition for locale if provided
      if (LocalizationParams().locale != null) {
        final localeString = '${LocalizationParams().locale!}';
        andConditions.add(sql.localization.locale.equals(localeString));
      }

      // Add conditions for modules and codes
      if (LocalizationParams().module != null &&
          LocalizationParams().module!.isNotEmpty) {
        final moduleToExclude = LocalizationParams().module!;

        if (LocalizationParams().exclude == true) {
          // Exclude modules but include records where the code matches
          final moduleCondition =
          sql.localization.module.contains(moduleToExclude).not();
          final codeCondition = LocalizationParams().code != null &&
              LocalizationParams().code!.isNotEmpty
              ? sql.localization.code.isIn(LocalizationParams().code!.toList())
              : const Constant(false); // True if no code filter

          // Combine conditions: exclude module unless code matches
          andConditions.add(buildAnd([moduleCondition | codeCondition]));
        } else {
          // Include specified modules and optionally filter by code
          final moduleCondition =
          sql.localization.module.contains(moduleToExclude);
          final codeCondition = LocalizationParams().code != null &&
              LocalizationParams().code!.isNotEmpty
              ? sql.localization.code.isIn(LocalizationParams().code!.toList())
              : const Constant(false);

          final moduleList =
          moduleToExclude.split(',').map((e) => e.trim()).toList();

          // Combine conditions: module matches and optionally code filter
          andConditions.add(
            buildOr([
              sql.localization.module.isIn(moduleList),
              codeCondition,
            ]),
          );
        }
      } else if (LocalizationParams().code != null &&
          LocalizationParams().code!.isNotEmpty) {
        // If no module filter, just apply code filter
        andConditions.add(
            sql.localization.code.isIn(LocalizationParams().code!.toList()));
      }

      // Apply the combined conditions to the query
      if (andConditions.isNotEmpty) {
        selectQuery.where(buildAnd(andConditions));
      }

      final result = await selectQuery.get();

      return result.map((row) {
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
    });
  }

  FutureOr<List<Localization>> fetchLocalization(
      {required LocalSqlDataStore sql,
        required String locale,
        required String module}) async {
    return retryLocalCallOperation(() async {
      final moduleList = module.split(',').map((e) => e.trim()).toList();

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
  }

  FutureOr create(
      List<LocalizationCompanion> result, LocalSqlDataStore sql) async {
    if (result.isEmpty) return;
    return retryLocalCallOperation(() async {
      final batchResult = await sql.batch((batch) {
        batch.insertAllOnConflictUpdate(sql.localization, result);
      });
      LocalizationSqlCache.invalidate();
      return batchResult;
    });
  }
}

/// Deduplicates identical localization SQL reads across all delegates.
///
/// Without this, each [LocalizationsDelegate] triggers a separate Drift query on
/// the UI isolate, which blocks frames and freezes the app.
class LocalizationSqlCache {
  LocalizationSqlCache._();

  static final LocalizationSqlCache instance = LocalizationSqlCache._();

  String? _cacheKey;
  List<Localization>? _cached;
  Future<List<Localization>>? _inFlight;

  static void invalidate() => instance._invalidate();

  void _invalidate() {
    _cacheKey = null;
    _cached = null;
    _inFlight = null;
  }

  String _currentKey() {
    final params = LocalizationParams();
    final codes = params.code;
    return [
      '${params.locale}',
      params.module ?? '',
      '${params.exclude}',
      codes == null ? '' : codes.join('\u0001'),
    ].join('|');
  }

  Future<List<Localization>> load(LocalSqlDataStore sql) {
    final key = _currentKey();

    if (_cached != null && _cacheKey == key) {
      return Future<List<Localization>>.value(_cached!);
    }

    if (_inFlight != null && _cacheKey == key) {
      return _inFlight!;
    }

    _cacheKey = key;
    _inFlight = LocalizationLocalRepository()
        .returnLocalizationFromSQLUncached(sql)
        .then((list) {
      _cached = list;
      _inFlight = null;
      return list;
    }).catchError((Object error, StackTrace stack) {
      _inFlight = null;
      if (_cacheKey == key) {
        _cacheKey = null;
        _cached = null;
      }
      Error.throwWithStackTrace(error, stack);
    });

    return _inFlight!;
  }
}