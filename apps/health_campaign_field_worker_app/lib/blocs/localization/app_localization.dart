import 'package:digit_data_model/data/local_store/sql_store/sql_store.dart';
import 'package:flutter/material.dart';

import '../../data/local_store/no_sql/schema/app_configuration.dart';
import '../../data/local_store/no_sql/schema/localization.dart';
import '../../data/repositories/local/localization.dart';
import 'app_localizations_delegate.dart';

class AppLocalizations {
  final Locale locale;
  final LocalSqlDataStore sql;

  AppLocalizations(this.locale, this.sql);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final List<Localization> _localizedStrings = <Localization>[];
  static Map<String, String> _messagesByCode = const {};

  static LocalizationsDelegate<AppLocalizations> getDelegate(
          AppConfiguration config, LocalSqlDataStore sql) =>
      AppLocalizationsDelegate(config, sql);

  Future<bool> load() async {
    final listOfLocalizations =
        await LocalizationLocalRepository().returnLocalizationFromSQL(sql);

    if (listOfLocalizations.isNotEmpty) {
      _localizedStrings
        ..clear()
        ..addAll(listOfLocalizations);
      _messagesByCode = {
        for (final entry in listOfLocalizations) entry.code: entry.message,
      };
    }

    return _localizedStrings.isNotEmpty;
  }

  static String? findMessage(String key) => _messagesByCode[key];

  String translate(String localizedValues) {
    if (_messagesByCode.isEmpty) {
      return localizedValues;
    }
    return _messagesByCode[localizedValues] ?? localizedValues;
  }
}
