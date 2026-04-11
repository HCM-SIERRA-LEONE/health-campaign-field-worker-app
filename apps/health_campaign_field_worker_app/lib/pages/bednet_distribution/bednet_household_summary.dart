import 'package:auto_route/auto_route.dart';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/models/entities/additional_fields_type.dart';

import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../router/app_router.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';

@RoutePage()
class BednetHouseholdSummaryPage extends LocalizedStatefulWidget {
  final String headName;
  final int memberCount;
  final String? mobileNumber;

  const BednetHouseholdSummaryPage({
    super.key,
    super.appLocalizations,
    required this.headName,
    required this.memberCount,
    this.mobileNumber,
  });

  @override
  State<BednetHouseholdSummaryPage> createState() =>
      _BednetHouseholdSummaryPageState();
}

class _BednetHouseholdSummaryPageState
    extends LocalizedState<BednetHouseholdSummaryPage> {
  static const Color _titleColor = Color(0xFF202124);
  static const Color _reminderBackground = Color(0xFFC6442D);

  int get _itnForDelivery => max(1, (widget.memberCount / 2).ceil());

  String _eTokenForHousehold(HouseholdModel? household) {
    final fromFields = household?.additionalFields?.fields
        .firstWhereOrNull(
            (field) => field.key == AdditionalFieldsType.eToken.toValue())
        ?.value
        ?.toString();
    if (fromFields != null && fromFields.isNotEmpty) return fromFields;
    final random = Random(widget.headName.hashCode + widget.memberCount);
    final part1 = (100 + random.nextInt(900)).toString();
    final part2 = (100 + random.nextInt(900)).toString();
    return 'E$part1-$part2';
  }

  Widget _infoRow(
      TextStyle labelStyle, TextStyle valueStyle, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: labelStyle),
          ),
          const SizedBox(width: spacer2),
          Expanded(
            flex: 3,
            child: Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    final bloc = context.read<BeneficiaryRegistrationBloc>();
    final household = bloc.state.mapOrNull(
      create: (value) => value.householdModel,
      summary: (value) => value.householdModel,
      persisted: (value) => value.householdModel,
      editHousehold: (value) => value.householdModel,
    );

    context.router.push(
      BednetEolinAssessmentRoute(
        eToken: _eTokenForHousehold(household),
        itnForDelivery: _itnForDelivery,
        householdClientReferenceId: household?.clientReferenceId,
        appLocalizations: localizations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    final household =
        context.read<BeneficiaryRegistrationBloc>().state.mapOrNull(
              create: (value) => value.householdModel,
              summary: (value) => value.householdModel,
              persisted: (value) => value.householdModel,
              editHousehold: (value) => value.householdModel,
            );

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const Column(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: spacer2),
              child: BackNavigationHelpHeaderWidget(showHelp: true),
            ),
          ],
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: localizations.translate(i18.common.coreCommonNext),
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              onPressed: _onNext,
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
                        localizations.translate(
                            i18.householdDetails.householdDetailsLabel),
                        style: textTheme.headingL.copyWith(
                          color: _titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      _infoRow(
                        textTheme.bodyS.copyWith(fontWeight: FontWeight.w700),
                        textTheme.bodyS,
                        localizations
                            .translate(i18.householdDetails.householdHeadLabel),
                        widget.headName,
                      ),
                      _infoRow(
                        textTheme.bodyS.copyWith(fontWeight: FontWeight.w700),
                        textTheme.bodyS,
                        localizations
                            .translate(i18.householdDetails.memberCountLabel),
                        widget.memberCount.toString().padLeft(2, '0'),
                      ),
                      _infoRow(
                        textTheme.bodyS.copyWith(fontWeight: FontWeight.w700),
                        textTheme.bodyS,
                        localizations.translate(
                            i18.householdDetails.itnForDeliveryLabel),
                        _itnForDelivery.toString(),
                      ),
                      _infoRow(
                        textTheme.bodyS.copyWith(fontWeight: FontWeight.w700),
                        textTheme.bodyS,
                        localizations
                            .translate(i18.common.coreCommonMobileNumber),
                        (widget.mobileNumber?.trim().isNotEmpty ?? false)
                            ? widget.mobileNumber!.trim()
                            : '--',
                      ),
                      _infoRow(
                        textTheme.bodyS.copyWith(fontWeight: FontWeight.w700),
                        textTheme.bodyS,
                        localizations
                            .translate(i18.householdDetails.eTokenLabel),
                        _eTokenForHousehold(household),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(spacer2),
                    color: _reminderBackground,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.error_outline,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: spacer2),
                        Expanded(
                          child: Text(
                            localizations.translate(
                              i18.householdOverView
                                  .householdOverViewEolinReminder,
                            ),
                            style: textTheme.bodyS.copyWith(
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
