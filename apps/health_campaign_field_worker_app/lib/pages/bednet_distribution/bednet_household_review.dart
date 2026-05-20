import 'dart:math';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';

import '../../blocs/localization/app_localization.dart';
import '../../router/app_router.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
// import '../../utils/registration_deliver_utils/utils.dart';
import '../../utils/utils.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'bednet_eolin_assessment.dart';

class BednetHouseholdReviewPage extends StatelessWidget {
  final String headName;
  final int memberCount;
  final int childrenCount;
  final String? mobileNumber;

  /// When set (e.g. from household [AdditionalFieldsType.eToken]), must match what
  /// users see elsewhere; otherwise a deterministic synthetic token is used.
  final String? householdEToken;

  /// When both set, [BednetInformHouseholdPage] persists delivery via repositories
  /// (overview bloc is not in [BeneficiaryRegistrationState.create]).
  final HouseholdModel? bednetDeliveryHousehold;
  final IndividualModel? bednetDeliveryHead;

  const BednetHouseholdReviewPage({
    super.key,
    required this.headName,
    required this.memberCount,
    required this.childrenCount,
    this.mobileNumber,
    this.householdEToken,
    this.bednetDeliveryHousehold,
    this.bednetDeliveryHead,
  });

  int get _itnForDelivery => min(4, max(1, (memberCount / 2).ceil()));

  /// Same algorithm as before; used only when [householdEToken] is null/empty.
  static String syntheticEToken({
    required String headName,
    required int memberCount,
  }) {
    final random = Random(headName.hashCode + memberCount);
    final part1 = (100 + random.nextInt(900)).toString();
    final part2 = (100 + random.nextInt(900)).toString();
    return 'E$part1-$part2';
  }

  String get _effectiveToken {
    final stored = householdEToken?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return syntheticEToken(headName: headName, memberCount: memberCount);
  }

  /// Returns false when the distributor cannot deliver [bednetsRequired] ITNs.
  Future<bool> _checkStockForItnDelivery(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final stockCount = RegistrationDeliverySingleton().stockCount;

    if (stockCount == null || stockCount >= _itnForDelivery) {
      return true;
    }

    showCustomPopup(
      context: context,
      builder: (popupContext) => Popup(
        title: localizations.translate(
          i18.beneficiaryDetails.insufficientStockHeading,
        ),
        onOutsideTap: () {
          Navigator.of(popupContext).pop();
        },
        description: localizations.translate(
          i18.beneficiaryDetails.insufficientStockDescription,
        ),
        type: PopUpType.simple,
        actions: [
          DigitButton(
            label: localizations.translate(i18.beneficiaryDetails.goToHome),
            onPressed: () {
              Navigator.of(popupContext, rootNavigator: true).pop();
              context.router.replaceAll([HomeRoute()]);
            },
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _onNextPressed(BuildContext context) async {
    if (!await _checkStockForItnDelivery(context)) return;
    if (!context.mounted) return;

    final registrationBloc = context.read<BeneficiaryRegistrationBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: registrationBloc,
          child: BednetEolinAssessmentPage(
            headName: headName,
            memberCount: memberCount,
            childrenCount: childrenCount,
            mobileNumber: mobileNumber,
            householdEToken: householdEToken,
            bednetDeliveryHousehold: bednetDeliveryHousehold,
            bednetDeliveryHead: bednetDeliveryHead,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const BackNavigationHelpHeaderWidget(showHelp: true),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Next',
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              onPressed: () => _onNextPressed(context),
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(spacer2),
              child: Column(
                children: [
                  DigitCard(
                    children: [
                      Text(
                        'Household Details',
                        style: textTheme.headingXl.copyWith(
                          color: theme.colorTheme.primary.primary2,
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      _kv('Household Head', headName),
                      _kv('Member Count',
                          memberCount.toString().padLeft(2, '0')),
                      _kv('Children Under 14',
                          childrenCount.toString().padLeft(2, '0')),
                      _kv('Number Of ITN For Delivery',
                          _itnForDelivery.toString()),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      _kv(
                          'Mobile Number',
                          mobileNumber?.isNotEmpty == true
                              ? mobileNumber!
                              : '--'),
                      _kv('E-Token', _effectiveToken),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      Container(
                        width: double.infinity,
                        color: const Color.fromARGB(255, 200, 76, 14),
                        padding: const EdgeInsets.all(spacer2),
                        child: Text(
                          'Ensure that $_itnForDelivery Bednets are given to $headName and proper Health Talk is provided!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key,
              style: TextStyle(
                fontWeight: key == 'Number Of ITN For Delivery'
                    ? FontWeight.w900
                    : FontWeight.bold,
                fontSize: key == 'Number Of ITN For Delivery' ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(width: spacer2),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: key == 'Number Of ITN For Delivery'
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: key == 'Number Of ITN For Delivery' ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
