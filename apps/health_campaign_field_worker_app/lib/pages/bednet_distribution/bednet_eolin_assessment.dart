import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/TextTheme/digit_text_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';

import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../router/app_router.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';

@RoutePage()
class BednetEolinAssessmentPage extends LocalizedStatefulWidget {
  final BeneficiaryRegistrationBloc registrationBloc;
  final String eToken;
  final int itnForDelivery;
  final String? householdClientReferenceId;
  final String? headIndividualClientReferenceId;

  const BednetEolinAssessmentPage({
    super.key,
    super.appLocalizations,
    required this.registrationBloc,
    required this.eToken,
    required this.itnForDelivery,
    this.householdClientReferenceId,
    this.headIndividualClientReferenceId,
  });

  @override
  State<BednetEolinAssessmentPage> createState() =>
      _BednetEolinAssessmentPageState();
}

class _BednetEolinAssessmentPageState
    extends LocalizedState<BednetEolinAssessmentPage> {
  static const int _maxReturnedNets = 999;
  static const Color _orange = Color(0xFFCC4C02);
  static const Color _titleColor = Color(0xFF005A7A);
  static const Color _reminderBackground = Color(0xFFC6442D);
  static const Color _stepperBorder = Color(0xFF505A5F);
  static const Color _stepperSideFill = Color(0xFFF0F0F0);
  static const Color _stepperCenterFill = Colors.white;

  bool? _hasOldNets;
  int _returnedCount = 0;
  bool _reminderVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.registrationBloc.clearPendingItnEolinAssessment();
    });
  }

  bool get _canProceed {
    if (_hasOldNets == null) return false;
    if (_hasOldNets == false) return true;
    return _returnedCount >= 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

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
              isDisabled: !_canProceed,
              onPressed: _onNext,
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(spacer2),
              child: DigitCard(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate(
                          i18.householdOverView
                              .householdOverViewEolinAssessmentTitle,
                        ),
                        style: textTheme.headingXl.copyWith(
                          color: _titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      Text(
                        localizations.translate(
                          i18.householdOverView
                              .householdOverViewEolinOldNetsQuestion,
                        ),
                        style: textTheme.label.copyWith(
                          color: theme.colorTheme.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacer1),
                      _choiceRow(
                        theme: theme,
                        textTheme: textTheme,
                        label:
                            localizations.translate(i18.common.coreCommonYes),
                        selected: _hasOldNets == true,
                        onTap: () => setState(() {
                          _hasOldNets = true;
                          _reminderVisible = true;
                        }),
                      ),
                      const SizedBox(height: spacer1),
                      _choiceRow(
                        theme: theme,
                        textTheme: textTheme,
                        label: localizations.translate(i18.common.coreCommonNo),
                        selected: _hasOldNets == false,
                        onTap: () => setState(() {
                          _hasOldNets = false;
                          _returnedCount = 0;
                        }),
                      ),
                      if (_hasOldNets == true) ...[
                        const SizedBox(height: spacer2),
                        LabeledField(
                          capitalizedFirstLetter: false,
                          label: localizations.translate(
                            i18.householdOverView
                                .householdOverViewEolinReturnCountLabel,
                          ),
                          labelStyle: textTheme.label.copyWith(
                            color: theme.colorTheme.text.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          child: _buildStepper(textTheme),
                        ),
                        if (_reminderVisible) ...[
                          const SizedBox(height: spacer2),
                          _buildReminderBanner(textTheme),
                        ],
                      ],
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

  Widget _choiceRow({
    required ThemeData theme,
    required DigitTextTheme textTheme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _orange, width: 2),
                  color: selected ? _orange : Colors.white,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: spacer2),
            Expanded(
              child: Text(
                label,
                style: textTheme.label.copyWith(
                  color: theme.colorTheme.text.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(DigitTextTheme textTheme) {
    const cellHeight = 48.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: _stepperBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: _stepperSideCell(
                height: cellHeight,
                symbol: '-',
                textTheme: textTheme,
                onTap: _returnedCount > 0
                    ? () => setState(() => _returnedCount--)
                    : null,
              ),
            ),
            Container(width: 1, color: _stepperBorder),
            Expanded(
              flex: 4,
              child: ColoredBox(
                color: _stepperCenterFill,
                child: Center(
                  child: Text(
                    _returnedCount.toString().padLeft(2, '0'),
                    style: textTheme.headingL.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, color: _stepperBorder),
            Expanded(
              flex: 1,
              child: _stepperSideCell(
                height: cellHeight,
                symbol: '+',
                textTheme: textTheme,
                onTap: _returnedCount < _maxReturnedNets
                    ? () => setState(() => _returnedCount++)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperSideCell({
    required double height,
    required String symbol,
    required DigitTextTheme textTheme,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _stepperSideFill,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Text(
              symbol,
              style: textTheme.headingL.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderBanner(DigitTextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(spacer2),
      color: _reminderBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: spacer2),
          Expanded(
            child: Text(
              localizations.translate(
                i18.householdOverView.householdOverViewEolinReminder,
              ),
              style: textTheme.bodyL.copyWith(
                color: Colors.white,
                height: 1.37,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _reminderVisible = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    if (!_canProceed) return;
    final has = _hasOldNets;
    if (has == null) return;
    widget.registrationBloc.setPendingItnEolinAssessment(
      hasOldNets: has,
      returnedNetsCount: has ? _returnedCount : null,
    );
    context.router.push(
      BednetInformHouseholdRoute(
        registrationBloc: widget.registrationBloc,
        eToken: widget.eToken,
        itnForDelivery: widget.itnForDelivery,
        appLocalizations: widget.appLocalizations,
      ),
    );
  }
}
