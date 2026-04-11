import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/TextTheme/digit_text_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:digit_data_model/data_model.dart';

import '../../models/entities/additional_fields_type.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_household_session.dart';
import 'bednet_tb_referral.dart';

/// TB Screening Eligibility Assessment page (HDDF-5036).
///
/// Logic:
///   - Q1 = Yes  → immediate referral flow
///   - 2+ Yes    → show additional symptom checkboxes → "Ready to Submit" modal → referral
///   - All No    → "Data recorded successfully" panel (no referral)
class BednetTbAssessmentPage extends LocalizedStatefulWidget {
  final String childLabel;
  final String sessionRowKey;
  final String? householdClientReferenceId;
  final String? childIndividualClientReferenceId;
  final String? projectBeneficiaryClientReferenceId;
  final VoidCallback? onBackToSearch;

  const BednetTbAssessmentPage({
    super.key,
    super.appLocalizations,
    required this.childLabel,
    required this.sessionRowKey,
    this.householdClientReferenceId,
    this.childIndividualClientReferenceId,
    this.projectBeneficiaryClientReferenceId,
    this.onBackToSearch,
  });

  @override
  State<BednetTbAssessmentPage> createState() => _BednetTbAssessmentPageState();
}

class _BednetTbAssessmentPageState
    extends LocalizedState<BednetTbAssessmentPage> {
  static const Color _orange = Color(0xFFCC4C02);
  static const Color _titleColor = Color(0xFF005A7A);
  static const Color _errorColor = Color(0xFFC6442D);
  static const Color _greenColor = Color(0xFF00703C);

  // 6 answers: true = Yes, false = No, null = unanswered
  final List<bool?> _answers = List.filled(6, null);

  // Additional symptoms checkboxes (shown when 2+ Yes)
  final Map<int, bool> _symptoms = {0: false, 1: false, 2: false};

  // Whether symptoms section was shown & user tried to submit without selection
  bool _symptomValidationError = false;

  // After all-No submission — show success inline
  bool _showNoReferralResult = false;

  List<String> get _questionKeys => [
        i18.tbAssessment.q1,
        i18.tbAssessment.q2,
        i18.tbAssessment.q3,
        i18.tbAssessment.q4,
        i18.tbAssessment.q5,
        i18.tbAssessment.q6,
      ];

  List<String> get _symptomKeys => [
        i18.tbAssessment.symNightSweats,
        i18.tbAssessment.symFatigue,
        i18.tbAssessment.symSwollenNodes,
      ];

  int get _yesCount => _answers.where((a) => a == true).length;

  bool get _allAnswered => _answers.every((a) => a != null);

  // Whether Q1 was answered Yes
  bool get _q1Yes => _answers[0] == true;

  // Show extra symptoms when ≥2 Yes AND Q1 was NOT the sole trigger
  bool get _showAdditionalSymptoms => _allAnswered && !_q1Yes && _yesCount >= 2;

  bool get _atLeastOneSymptomSelected => _symptoms.values.any((v) => v == true);

  bool get _canSubmit {
    if (!_allAnswered) return false;
    if (_showAdditionalSymptoms && !_atLeastOneSymptomSelected) return false;
    return true;
  }

  List<String> get _selectedSymptomKeys => _symptoms.entries
      .where((entry) => entry.value)
      .map((entry) => _symptomKeys[entry.key])
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    if (_showNoReferralResult) {
      return _buildNoReferralResult(theme, textTheme);
    }

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: spacer2),
              child: BackNavigationHelpHeaderWidget(showHelp: false),
            ),
          ],
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: localizations.translate(i18.common.coreCommonSubmit),
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              isDisabled: !_canSubmit,
              onPressed: _onSubmit,
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(spacer2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title card ─────────────────────────────────────────────
                  DigitCard(
                    children: [
                      Text(
                        localizations
                            .translate(i18.tbAssessment.screeningTitle),
                        style: textTheme.headingXl.copyWith(
                          color: _titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacer1),
                      Text(
                        '${localizations.translate(i18.tbAssessment.screeningSubtitle)} — ${widget.childLabel}',
                        style: textTheme.bodyS.copyWith(
                          color: theme.colorTheme.text.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacer2),

                  // ── Screening questions card ────────────────────────────────
                  DigitCard(
                    children: [
                      ...List.generate(_questionKeys.length, (idx) {
                        return _buildQuestion(
                          theme: theme,
                          textTheme: textTheme,
                          index: idx,
                          questionKey: _questionKeys[idx],
                        );
                      }),
                    ],
                  ),

                  // ── Additional symptoms card (conditionally shown) ──────────
                  if (_showAdditionalSymptoms) ...[
                    const SizedBox(height: spacer2),
                    _buildAdditionalSymptomsCard(theme, textTheme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion({
    required ThemeData theme,
    required DigitTextTheme textTheme,
    required int index,
    required String questionKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${localizations.translate(questionKey)}',
            style: textTheme.bodyL.copyWith(
              color: theme.colorTheme.text.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: spacer1),
          Row(
            children: [
              _choiceChip(
                theme: theme,
                textTheme: textTheme,
                label: localizations.translate(i18.common.coreCommonYes),
                selected: _answers[index] == true,
                onTap: () => _setAnswer(index, true),
              ),
              const SizedBox(width: spacer2),
              _choiceChip(
                theme: theme,
                textTheme: textTheme,
                label: localizations.translate(i18.common.coreCommonNo),
                selected: _answers[index] == false,
                onTap: () => _setAnswer(index, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required ThemeData theme,
    required DigitTextTheme textTheme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: spacer3, vertical: spacer1),
        decoration: BoxDecoration(
          color: selected ? _orange : Colors.white,
          border: Border.all(color: _orange, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : _orange,
                    width: 2,
                  ),
                  color: selected ? _orange : Colors.white,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: spacer1),
            Text(
              label,
              style: textTheme.bodyL.copyWith(
                color: selected ? Colors.white : theme.colorTheme.text.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalSymptomsCard(
      ThemeData theme, DigitTextTheme textTheme) {
    return DigitCard(
      children: [
        Text(
          localizations.translate(i18.tbAssessment.additionalSymptomsTitle),
          style: textTheme.headingM.copyWith(
            color: _titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: spacer1),
        Text(
          localizations.translate(i18.tbAssessment.additionalSymptomsSubtitle),
          style: textTheme.bodyS.copyWith(
            color: theme.colorTheme.text.secondary,
          ),
        ),
        const SizedBox(height: spacer2),
        ...List.generate(_symptomKeys.length, (idx) {
          return _buildCheckboxRow(
            theme: theme,
            textTheme: textTheme,
            label: localizations.translate(_symptomKeys[idx]),
            checked: _symptoms[idx] ?? false,
            onTap: () => setState(() {
              _symptoms[idx] = !(_symptoms[idx] ?? false);
              _symptomValidationError = false;
            }),
          );
        }),
        if (_symptomValidationError) ...[
          const SizedBox(height: spacer1),
          Text(
            localizations.translate(i18.tbAssessment.selectAtLeastOneSymptom),
            style: textTheme.bodyS.copyWith(color: _errorColor),
          ),
        ],
      ],
    );
  }

  Widget _buildCheckboxRow({
    required ThemeData theme,
    required DigitTextTheme textTheme,
    required String label,
    required bool checked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: spacer2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? _orange : Colors.white,
                border: Border.all(color: _orange, width: 1.5),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: spacer2),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyL.copyWith(
                  color: theme.colorTheme.text.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoReferralResult(ThemeData theme, DigitTextTheme textTheme) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(spacer2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: spacer4),
                Icon(Icons.check_circle_outline, size: 72, color: _greenColor),
                const SizedBox(height: spacer2),
                Text(
                  localizations.translate(
                    i18.acknowledgementSuccess.acknowledgementLabelText,
                  ),
                  style: textTheme.headingXl.copyWith(
                    color: _greenColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: spacer1),
                Text(
                  localizations.translate(i18.tbAssessment.noReferralNeeded),
                  style: textTheme.bodyL.copyWith(
                    color: theme.colorTheme.text.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                DigitButton(
                  label: localizations.translate(
                    i18.householdDetails.viewHouseHoldDetailsAction,
                  ),
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: () {
                    BednetHouseholdSession.markTbScreened(widget.sessionRowKey);
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: spacer2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setAnswer(int idx, bool value) {
    setState(() {
      _answers[idx] = value;
      // If Q1 is changed, re-evaluate
      _symptomValidationError = false;
      _showNoReferralResult = false;
    });
  }

  Future<void> _onSubmit() async {
    if (!_allAnswered) return;

    // Q1=Yes → go directly to referral
    if (_q1Yes) {
      await _navigateToReferral();
      return;
    }

    // 2+ Yes → require additional symptoms
    if (_yesCount >= 2) {
      if (_showAdditionalSymptoms && !_atLeastOneSymptomSelected) {
        setState(() => _symptomValidationError = true);
        return;
      }
      // Show ready-to-submit modal
      final proceed = await _showReadyToSubmitDialog();
      if (proceed == true && mounted) {
        await _navigateToReferral();
      }
      return;
    }

    // All No → record result
    await _persistScreeningOutcome(referred: false);
    if (!mounted) return;
    setState(() => _showNoReferralResult = true);
  }

  Future<bool?> _showReadyToSubmitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations.translate(i18.tbAssessment.readyToSubmit),
        description:
            localizations.translate(i18.tbAssessment.readyToSubmitContent),
        actions: [
          DigitButton(
            label: localizations.translate(i18.beneficiaryDetails.ctaProceed),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          DigitButton(
            label: localizations.translate(i18.common.coreCommonCancel),
            type: DigitButtonType.tertiary,
            size: DigitButtonSize.large,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToReferral() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BednetTbReferralPage(
          childLabel: widget.childLabel,
          sessionRowKey: widget.sessionRowKey,
          householdClientReferenceId: widget.householdClientReferenceId,
          childIndividualClientReferenceId:
              widget.childIndividualClientReferenceId,
          projectBeneficiaryClientReferenceId:
              widget.projectBeneficiaryClientReferenceId,
          screeningAnswers: _answers.whereType<bool>().toList(growable: false),
          selectedSymptomKeys: _selectedSymptomKeys,
          onBackToSearch: widget.onBackToSearch,
        ),
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _persistScreeningOutcome({required bool referred}) async {
    if (widget.projectBeneficiaryClientReferenceId == null) return;

    final taskRepository =
        context.repository<TaskModel, TaskSearchModel>(context);
    final now = context.millisecondsSinceEpoch();
    final taskClientReferenceId = IdGen.i.identifier;
    final boundary = RegistrationDeliverySingleton().boundary;
    final areaName = boundary?.name ?? '';
    final areaCode = boundary?.code ?? '';

    final screeningTask = TaskModel(
      projectBeneficiaryClientReferenceId:
          widget.projectBeneficiaryClientReferenceId,
      clientReferenceId: taskClientReferenceId,
      projectId: RegistrationDeliverySingleton().projectId,
      tenantId: RegistrationDeliverySingleton().tenantId,
      rowVersion: 1,
      status: referred
          ? Status.beneficiaryReferred.toValue()
          : Status.visited.toValue(),
      additionalFields: TaskAdditionalFields(
        version: 1,
        fields: [
          AdditionalField(
            'taskStatus',
            referred
                ? Status.beneficiaryReferred.toValue()
                : Status.visited.toValue(),
          ),
          AdditionalField('tbAssessmentCompleted', true.toString()),
          AdditionalField('tbAssessmentQuestions', _answers.join(',')),
          AdditionalField(
            'tbAssessmentSymptoms',
            _selectedSymptomKeys.join(','),
          ),
          AdditionalField(
            'householdClientReferenceId',
            widget.householdClientReferenceId,
          ),
          AdditionalField(
            'childIndividualClientReferenceId',
            widget.childIndividualClientReferenceId,
          ),
          AdditionalField('administrativeArea', areaName),
          AdditionalField('administrativeAreaCode', areaCode),
          AdditionalField(
            AdditionalFieldsType.dateOfVerification.toValue(),
            now.toString(),
          ),
          AdditionalField(
            AdditionalFieldsType.cycleIndex.toValue(),
            '0${context.selectedCycle?.id ?? 1}',
          ),
        ],
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: now,
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: now,
      ),
      auditDetails: AuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: now,
      ),
    );

    await taskRepository.create(screeningTask);
  }
}
