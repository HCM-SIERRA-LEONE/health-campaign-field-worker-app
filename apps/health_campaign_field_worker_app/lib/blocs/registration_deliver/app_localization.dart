import 'package:flutter/material.dart';

import '../../data/local_store/no_sql/schema/localization.dart';
import '../localization/app_localization.dart';
import 'registration_delivery_localization_delegate.dart';

// Class responsible for handling attendance localization
class RegistrationDeliveryLocalization {
  final Locale locale;
  final Future<dynamic> localizedStrings;
  final List<dynamic> languages;

  RegistrationDeliveryLocalization(
      this.locale, this.localizedStrings, this.languages);

  // Method to get the current localization instance from context
  static RegistrationDeliveryLocalization of(BuildContext context) {
    return Localizations.of<RegistrationDeliveryLocalization>(
        context, RegistrationDeliveryLocalization)!;
  }

  static final List<dynamic> _localizedStrings = <dynamic>[];

  // Method to get the delegate for localization
  static LocalizationsDelegate<RegistrationDeliveryLocalization> getDelegate(
          Future<dynamic> localizedStrings, List<dynamic> languages) =>
      RegistrationDeliveryLocalizationDelegate(localizedStrings, languages);

  // Method to load localized strings
  Future<bool> load() async {
    // _localizedStrings.clear();
    // Iterate over localized strings and filter based on locale
    for (var element in await localizedStrings) {
      if (element.locale == '${locale.languageCode}_${locale.countryCode}') {
        final index = _localizedStrings.indexWhere(
              (existing) => existing.code == element.code,
        );
        if (index != -1) {
          _localizedStrings[index] = element;
        } else {
          _localizedStrings.add(element);
        }
      }
    }

    return true;
  }

  // Method to translate a given localized value
  String translate(String localizedValues) {
    if (_localizedStrings.isNotEmpty) {
      final index = _localizedStrings.indexWhere(
        (medium) => (medium as Localization).code == localizedValues,
      );
      if (index != -1) return (_localizedStrings[index] as Localization).message;
    }
    return AppLocalizations.findMessage(localizedValues) ?? localizedValues;
  }
}
