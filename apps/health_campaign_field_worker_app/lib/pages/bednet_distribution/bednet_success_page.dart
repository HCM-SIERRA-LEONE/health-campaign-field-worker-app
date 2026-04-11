import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../router/app_router.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../widgets/registartion_deliver/localized.dart';

/// Success screen after bednet "inform household" submit.
///
/// Routing matches [HouseholdAcknowledgementPage]: this flow uses the
/// [Navigator] stack on top of [SearchBeneficiaryRoute], so "View household"
/// pops back to [HouseHoldDetailsPage] and "Back to search" clears search
/// state and pops to the search screen.
@RoutePage()
class BednetSuccessPage extends LocalizedStatefulWidget {
  final String eToken;
  final int itnForDelivery;

  const BednetSuccessPage({
    super.key,
    super.appLocalizations,
    required this.eToken,
    required this.itnForDelivery,
  });

  @override
  State<BednetSuccessPage> createState() => _BednetSuccessPageState();
}

class _BednetSuccessPageState extends LocalizedState<BednetSuccessPage> {
  static const Color _successGreen = Color(0xFF0B7A3E);

  void _onViewHouseholdDetails() {
    if (!mounted) return;
    context.router.popUntilRouteWithName(BednetHouseholdSummaryRoute.name);
  }

  void _onBackToSearch() {
    if (!mounted) return;
    context
        .read<SearchHouseholdsBloc>()
        .add(const SearchHouseholdsEvent.clear());
    context.router.popUntilRouteWithName(SearchBeneficiaryRoute.name);
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
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: _successGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: spacer3,
                          vertical: spacer4,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Give - ${widget.itnForDelivery} Bednets',
                              textAlign: TextAlign.center,
                              style: textTheme.headingL.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: spacer3),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 36,
                            ),
                            const SizedBox(height: spacer2),
                            Text(
                              localizations.translate(
                                i18.bednetDistribution.informSuccessETokenLabel,
                              ),
                              textAlign: TextAlign.center,
                              style: textTheme.bodyS.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.eToken,
                              textAlign: TextAlign.center,
                              style: textTheme.headingM.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: spacer2),
                            Text(
                              localizations.translate(
                                i18.bednetDistribution.informSuccessMessage,
                              ),
                              textAlign: TextAlign.center,
                              style: textTheme.bodyS.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(spacer2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            DigitButton(
                              label: localizations.translate(
                                i18.acknowledgementSuccess.actionLabelText,
                              ),
                              type: DigitButtonType.secondary,
                              size: DigitButtonSize.large,
                              mainAxisSize: MainAxisSize.max,
                              onPressed: _onBackToSearch,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
