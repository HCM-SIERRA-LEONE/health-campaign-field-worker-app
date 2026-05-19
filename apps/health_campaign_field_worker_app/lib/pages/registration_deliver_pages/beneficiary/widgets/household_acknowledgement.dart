import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/localization/app_localization.dart';
import '../../../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../../models/registration_deliver_model/entities/additional_fields_type.dart';
import '../../../../router/app_router.dart';
import '../../../../utils/registration_deliver_utils/constants.dart';
import '../../../../utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import '../../../../utils/registration_deliver_utils/utils.dart';
import '../../../../utils/utils.dart' as stock_utils;
import '../../../../widgets/registartion_deliver/localized.dart';

@RoutePage()
class HouseholdAcknowledgementPage extends LocalizedStatefulWidget {
  final bool? enableViewHousehold;
  final bool isChildRegistrationLoop;
  final String? householdClientRefIdForLoop;

  const HouseholdAcknowledgementPage({
    super.key,
    super.appLocalizations,
    this.enableViewHousehold,
    this.isChildRegistrationLoop = false,
    this.householdClientRefIdForLoop,
  });

  @override
  State<HouseholdAcknowledgementPage> createState() =>
      HouseholdAcknowledgementPageState();
}

class HouseholdAcknowledgementPageState
    extends LocalizedState<HouseholdAcknowledgementPage> {
  /// Get the declared children count from household registration
  int _getDeclaredChildrenCount(HouseholdModel household) {
    final fields = household.additionalFields?.fields;
    if (fields == null) return 0;
    final raw = fields
        .firstWhere(
          (f) => f.key == 'childrenUnder14',
          orElse: () => const AdditionalField('childrenUnder14', '0'),
        )
        .value
        ?.toString();
    return int.tryParse(raw ?? '0') ?? 0;
  }

  /// Open add child screen
  Future<void> _openAddChildScreen(
    BuildContext context,
    HouseholdModel household,
    dynamic addressModel,
  ) async {
    await _checkStockAndProceed(
      context,
      onSuccess: () async {
        if (context.mounted) {
          await context.router.push(
            CustomBednetIndividualDetailsWrapperRoute(
              householdModel: household,
              addressModel: addressModel,
              individualModel: null,
              projectBeneficiaryModel: null,
              isHeadOfHousehold: false,
            ),
          );
        }
      },
    );
  }

  /// Check stock before proceeding
  Future<void> _checkStockAndProceed(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) async {
    final localizations = AppLocalizations.of(context);
    final stockCount = stock_utils.RegistrationDeliverySingleton().stockCount;

    if (stockCount != null && stockCount <= 0) {
      showCustomPopup(
        context: context,
        builder: (popupContext) => Popup(
          title: localizations.translate(
            i18.beneficiaryDetails.insufficientStockHeading,
          ),
          onOutsideTap: () {
            Navigator.of(popupContext).pop(false);
          },
          description: localizations.translate(
            i18.beneficiaryDetails.insufficientStockDescription,
          ),
          type: PopUpType.simple,
          actions: [
            DigitButton(
              label: localizations.translate(i18.common.coreCommonOk),
              onPressed: () {
                Navigator.of(popupContext).pop();
              },
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
            ),
          ],
        ),
      );
    } else {
      onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
          builder: (context, householdState) {
            final wrapper = householdState.householdMemberWrapper;
            final household = wrapper.household;

            // Check if more children need to be registered
            bool shouldShowRegisterChildButton = false;
            if (widget.isChildRegistrationLoop && household != null) {
              final declaredChildrenCount =
                  _getDeclaredChildrenCount(household);
              final registeredMemberCount = wrapper.members?.length ?? 0;
              shouldShowRegisterChildButton =
                  (registeredMemberCount - 1) < declaredChildrenCount;
            }

            return Padding(
              padding: const EdgeInsets.all(spacer2),
              child: PanelCard(
                type: PanelType.success,
                description: localizations.translate(
                  i18.acknowledgementSuccess.acknowledgementDescriptionText,
                ),
                title: localizations.translate(
                  i18.acknowledgementSuccess.acknowledgementLabelText,
                ),
                actions: [
                  DigitButton(
                      label: localizations.translate(
                        i18.householdDetails.viewHouseHoldDetailsAction,
                      ),
                      // isDisabled: !(widget.enableViewHousehold ?? false),
                      onPressed: () async {
                        // Use the same navigation shape as [SearchBeneficiaryPage]:
                        // `replace(CustomHouseholdOverviewRoute)` can resolve the wrong
                        // [StackRouter] for nested routes and fall back to the bednet shell
                        // initial route ([BeneficiaryTypeSelectionRoute]).
                        await context.router.navigate(
                          BednetHouseholdOverviewWrapperRoute(
                            children: [
                              CustomHouseholdOverviewRoute(),
                            ],
                          ),
                        );
                      },
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large),
                  if (shouldShowRegisterChildButton)
                    DigitButton(
                      label: localizations.translate(
                        'REGISTER_NEXT_CHILD',
                      ),
                      onPressed: () async {
                        final address = household?.address;
                        if (address != null) {
                          await _openAddChildScreen(
                              context, household!, address);
                        }
                      },
                      type: DigitButtonType.secondary,
                      size: DigitButtonSize.large,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
