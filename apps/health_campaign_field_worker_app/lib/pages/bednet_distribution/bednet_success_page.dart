import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/localization/app_localization.dart';
import '../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../models/entities/additional_fields_type.dart';
import '../../router/app_router.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/localized.dart';

/// Shown as a Material route on top of the ITN chain (review → EOLIN → inform →
/// success). "View household" must pop that entire overlay, then
/// [StackRouter.navigate] to [CustomHouseholdOverviewRoute] (see [_onViewHouseholdDetails]).
class BednetSuccessPage extends LocalizedStatefulWidget {
  final String eToken;
  final int itnForDelivery;
  final HouseholdModel? householdModel;
  final AddressModel? addressModel;

  const BednetSuccessPage({
    super.key,
    super.appLocalizations,
    required this.eToken,
    required this.itnForDelivery,
    this.householdModel,
    this.addressModel,
  });

  @override
  State<BednetSuccessPage> createState() => _BednetSuccessPageState();
}

class _BednetSuccessPageState extends LocalizedState<BednetSuccessPage> {
  /// Get the declared children count from household registration
  int _getDeclaredChildrenCount(HouseholdModel household) {
    final fields = household.additionalFields?.fields;
    if (fields == null) return 0;
    final raw = fields
        .firstWhere(
          (f) => f.key == AdditionalFieldsType.childrenUnder14.toValue(),
          orElse: () => AdditionalField(
              AdditionalFieldsType.childrenUnder14.toValue(), '0'),
        )
        .value
        ?.toString();
    return int.tryParse(raw ?? '0') ?? 0;
  }

  /// Open add child screen (stock is checked before ITN delivery on review page).
  Future<void> _openAddChildScreen(
    BuildContext context,
    HouseholdModel household,
    AddressModel addressModel,
  ) async {
    if (!context.mounted) return;
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

  void _dispatchHouseholdOverviewReload() {
    final projectId = RegistrationDeliverySingleton().projectId;
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType;
    if (projectId == null || beneficiaryType == null) return;
    try {
      context.read<HouseholdOverviewBloc>().add(
            HouseholdOverviewReloadEvent(
              projectId: projectId,
              projectBeneficiaryType: beneficiaryType,
              offset: 0,
              limit: 1000,
            ),
          );
    } catch (_) {}
  }

  /// Pops the full ITN Material stack (success → EOLIN → review → …) until the
  /// nested navigator is back at the first route ([CustomHouseholdOverviewPage]
  /// under [BednetHouseholdOverviewWrapperRoute]), then aligns auto_route to that
  /// child — same shape as [HouseholdAcknowledgementPage] (see comment there on
  /// `navigate` vs `replace`).
  Future<void> _onViewHouseholdDetails() async {
    if (!mounted) return;
    _dispatchHouseholdOverviewReload();
    final rootRouter = context.router.root;
    // A single [Navigator.pop] only removed success and exposed [BednetEolinAssessmentPage].
    Navigator.of(context).popUntil((route) => route.isFirst);
    await rootRouter.navigate(
      BednetHouseholdOverviewWrapperRoute(
        children: [
          CustomHouseholdOverviewRoute(),
        ],
      ),
    );
  }

  void _onBackToSearch() {
    if (!mounted) return;
    try {
      context
          .read<SearchHouseholdsBloc>()
          .add(const SearchHouseholdsEvent.clear());
    } catch (_) {}

    final root = context.router.root;
    final nav = Navigator.of(context);
    // Pop all routes until the first one to clear the entire navigation stack
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      root.navigate(SearchBeneficiaryRoute());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(spacer2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DigitCard(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        left: spacer8,
                        right: spacer8,
                        top: spacer9,
                        bottom: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(spacer2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            localizations
                                .translate(
                                  i18.bednetDistribution
                                      .informSuccessBednetsDelivered,
                                )
                                .replaceAll(
                                  '{count}',
                                  widget.itnForDelivery.toString(),
                                ),
                            style: textTheme.headingM.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: spacer2),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Color(0xFF0B8D46),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: spacer1),
                          Text(
                            localizations.translate(
                              i18.bednetDistribution.informSuccessETokenLabel,
                            ),
                            style: textTheme.bodyS.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: spacer7),
                          SelectableText(
                            widget.eToken,
                            style: textTheme.headingL.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: spacer1),
                    Center(
                      child: Text(
                        localizations.translate(
                          i18.bednetDistribution.informSuccessMessage,
                        ),
                        style: textTheme.bodyS,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: spacer2),
                DigitButton(
                  label: localizations.translate(
                    i18.householdDetails.viewHouseHoldDetailsAction,
                  ),
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: _onViewHouseholdDetails,
                ),
                const SizedBox(height: spacer2),
                if (widget.householdModel != null &&
                    widget.addressModel != null &&
                    _getDeclaredChildrenCount(widget.householdModel!) > 0)
                  DigitButton(
                    label: localizations.translate('REGISTER_ELIGIBLE_CHILD'),
                    type: DigitButtonType.secondary,
                    size: DigitButtonSize.large,
                    mainAxisSize: MainAxisSize.max,
                    onPressed: () async {
                      await _openAddChildScreen(
                        context,
                        widget.householdModel!,
                        widget.addressModel!,
                      );
                    },
                  ),
                if (widget.householdModel != null &&
                    widget.addressModel != null &&
                    _getDeclaredChildrenCount(widget.householdModel!) > 0)
                  const SizedBox(height: spacer2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
