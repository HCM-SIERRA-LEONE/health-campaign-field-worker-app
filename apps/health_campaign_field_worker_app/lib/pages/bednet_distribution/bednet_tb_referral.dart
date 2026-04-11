import 'package:digit_data_model/data_model.dart'
    hide ReferralAdditionalFields, ReferralModel, ReferralSearchModel;
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/TextTheme/digit_text_theme.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/digit_search_bar.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../models/entities/additional_fields_type.dart';
import '../../models/registration_deliver_model/entities/referral.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import '../../router/app_router.dart';
import '../../utils/registration_deliver_utils/constants.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/component_wrapper/facility_bloc_wrapper.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_household_session.dart';

/// TB Referral Details screen (HDDF-5036).
///
/// Captures: Date of Referral, Administrative Unit, Referred To, Referred By.
/// On submit shows "Data recorded successfully" panel.
class BednetTbReferralPage extends LocalizedStatefulWidget {
  final String childLabel;
  final String sessionRowKey;
  final String? householdClientReferenceId;
  final String? childIndividualClientReferenceId;
  final String? projectBeneficiaryClientReferenceId;
  final List<bool> screeningAnswers;
  final List<String> selectedSymptomKeys;
  final VoidCallback? onBackToSearch;

  const BednetTbReferralPage({
    super.key,
    super.appLocalizations,
    required this.childLabel,
    required this.sessionRowKey,
    required this.screeningAnswers,
    required this.selectedSymptomKeys,
    this.householdClientReferenceId,
    this.childIndividualClientReferenceId,
    this.projectBeneficiaryClientReferenceId,
    this.onBackToSearch,
  });

  @override
  State<BednetTbReferralPage> createState() => _BednetTbReferralPageState();
}

class _BednetTbReferralPageState extends LocalizedState<BednetTbReferralPage> {
  static const Color _titleColor = Color(0xFF005A7A);

  static const _dateKey = 'dateOfReferral';
  static const _adminUnitKey = 'adminUnit';
  static const _referredToKey = 'referredTo';
  static const _referredByKey = 'referredBy';

  bool _submitted = false;
  FacilityModel? _selectedFacility;

  late final FormGroup _form;

  @override
  void initState() {
    super.initState();
    final loggedInUser =
        RegistrationDeliverySingleton().loggedInUser?.name ?? '';
    _form = FormGroup({
      _dateKey: FormControl<DateTime>(
        value: DateTime.now(),
        validators: [Validators.required],
      ),
      _adminUnitKey: FormControl<String>(
        value: RegistrationDeliverySingleton().boundary?.name ?? '',
        validators: [Validators.required],
      ),
      _referredToKey: FormControl<String>(
        validators: [Validators.required],
      ),
      _referredByKey: FormControl<String>(
        value: loggedInUser,
        validators: [Validators.required],
      ),
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    if (_submitted) {
      return _buildSuccessScreen(theme, textTheme);
    }

    return ReactiveForm(
      formGroup: _form,
      child: Scaffold(
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
                onPressed: _onSubmit,
              ),
            ],
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(spacer2),
                child: DigitCard(
                  children: [
                    Text(
                      localizations.translate(i18.tbAssessment.referralTitle),
                      style: textTheme.headingXl.copyWith(
                        color: _titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.childLabel,
                      style: textTheme.bodyS.copyWith(
                        color: theme.colorTheme.text.secondary,
                      ),
                    ),
                    const SizedBox(height: spacer3),

                    // Date of Referral
                    ReactiveWrapperField<DateTime>(
                      formControlName: _dateKey,
                      validationMessages: {
                        ValidationMessage.required: (_) => localizations
                            .translate(i18.common.corecommonRequired),
                      },
                      builder: (field) => LabeledField(
                        label: localizations
                            .translate(i18.tbAssessment.dateOfReferral),
                        isRequired: true,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  field.control.value ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              cancelText: localizations
                                  .translate(i18.common.coreCommonCancel),
                              confirmText: localizations
                                  .translate(i18.common.coreCommonOk),
                            );
                            if (picked != null) {
                              field.control.value = picked;
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              errorText: field.errorText,
                            ),
                            child: Text(
                              field.control.value != null
                                  ? DateFormat(Constants().dateFormat).format(
                                      field.control.value as DateTime,
                                    )
                                  : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: spacer2),

                    // Administrative Unit
                    ReactiveWrapperField<String>(
                      formControlName: _adminUnitKey,
                      validationMessages: {
                        ValidationMessage.required: (_) => localizations
                            .translate(i18.common.corecommonRequired),
                      },
                      builder: (field) => LabeledField(
                        label:
                            localizations.translate(i18.tbAssessment.adminUnit),
                        isRequired: true,
                        child: DigitTextFormInput(
                          initialValue: field.control.value as String? ?? '',
                          onChange: (value) => field.control.value = value,
                          errorMessage: field.errorText,
                        ),
                      ),
                    ),
                    const SizedBox(height: spacer2),

                    // Referred To
                    ReactiveWrapperField<String>(
                      formControlName: _referredToKey,
                      validationMessages: {
                        ValidationMessage.required: (_) => localizations
                            .translate(i18.tbAssessment.facilityRequired),
                      },
                      builder: (field) => LabeledField(
                        label: localizations
                            .translate(i18.tbAssessment.referredTo),
                        isRequired: true,
                        child: InkWell(
                          onTap: _selectFacility,
                          child: AbsorbPointer(
                            child: DigitTextFormInput(
                              initialValue:
                                  field.control.value as String? ?? '',
                              suffixIcon: Icons.search,
                              errorMessage: field.errorText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: spacer2),

                    // Referred By
                    ReactiveWrapperField<String>(
                      formControlName: _referredByKey,
                      validationMessages: {
                        ValidationMessage.required: (_) => localizations
                            .translate(i18.common.corecommonRequired),
                      },
                      builder: (field) => LabeledField(
                        label: localizations
                            .translate(i18.tbAssessment.referredBy),
                        isRequired: true,
                        child: DigitTextFormInput(
                          initialValue: field.control.value as String? ?? '',
                          onChange: (value) => field.control.value = value,
                          errorMessage: field.errorText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen(ThemeData theme, DigitTextTheme textTheme) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(spacer2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelCard(
                  type: PanelType.success,
                  title: localizations.translate(
                    i18.acknowledgementSuccess.acknowledgementLabelText,
                  ),
                  description: localizations.translate(
                    i18.acknowledgementSuccess.acknowledgementDescriptionText,
                  ),
                  actions: const [],
                ),
                const SizedBox(height: spacer2),
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
                DigitButton(
                  label: localizations.translate(
                    i18.acknowledgementSuccess.actionLabelText,
                  ),
                  type: DigitButtonType.secondary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: () {
                    BednetHouseholdSession.markTbScreened(widget.sessionRowKey);
                    widget.onBackToSearch?.call();
                    context.router.popUntilRouteWithName(
                      SearchBeneficiaryRoute.name,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    _form.markAllAsTouched();
    if (!_form.valid) return;
    if (_selectedFacility == null ||
        widget.projectBeneficiaryClientReferenceId == null) {
      _form.control(_referredToKey).markAsTouched();
      _form.control(_referredToKey).setErrors({'required': true});
      setState(() {});
      return;
    }

    final now = context.millisecondsSinceEpoch();
    final userId = RegistrationDeliverySingleton().loggedInUserUuid!;
    final projectId = RegistrationDeliverySingleton().projectId;
    final tenantId = RegistrationDeliverySingleton().tenantId;
    final boundary = RegistrationDeliverySingleton().boundary;

    final taskRepository =
        context.repository<TaskModel, TaskSearchModel>(context);
    final referralRepository =
        context.repository<ReferralModel, ReferralSearchModel>(context);

    final screeningTask = TaskModel(
      projectBeneficiaryClientReferenceId:
          widget.projectBeneficiaryClientReferenceId,
      clientReferenceId: IdGen.i.identifier,
      projectId: projectId,
      tenantId: tenantId,
      rowVersion: 1,
      status: Status.beneficiaryReferred.toValue(),
      additionalFields: TaskAdditionalFields(
        version: 1,
        fields: [
          AdditionalField(
            'taskStatus',
            Status.beneficiaryReferred.toValue(),
          ),
          AdditionalField('tbAssessmentCompleted', true.toString()),
          AdditionalField(
            'tbAssessmentQuestions',
            widget.screeningAnswers.join(','),
          ),
          AdditionalField(
            'tbAssessmentSymptoms',
            widget.selectedSymptomKeys.join(','),
          ),
          AdditionalField(
            'householdClientReferenceId',
            widget.householdClientReferenceId,
          ),
          AdditionalField(
            'childIndividualClientReferenceId',
            widget.childIndividualClientReferenceId,
          ),
          AdditionalField('administrativeArea', boundary?.name),
          AdditionalField('administrativeAreaCode', boundary?.code),
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
        createdBy: userId,
        createdTime: now,
        lastModifiedBy: userId,
        lastModifiedTime: now,
      ),
      auditDetails: AuditDetails(
        createdBy: userId,
        createdTime: now,
      ),
    );

    final referral = ReferralModel(
      clientReferenceId: IdGen.i.identifier,
      projectId: projectId,
      tenantId: tenantId,
      rowVersion: 1,
      projectBeneficiaryClientReferenceId:
          widget.projectBeneficiaryClientReferenceId,
      referrerId: userId,
      recipientType: 'FACILITY',
      recipientId: _selectedFacility!.id,
      reasons: _referralReasons(),
      additionalFields: ReferralAdditionalFields(
        version: 1,
        fields: [
          AdditionalField(
            'dateOfReferral',
            (_form.control(_dateKey).value as DateTime)
                .millisecondsSinceEpoch
                .toString(),
          ),
          AdditionalField(
            'administrativeArea',
            _form.control(_adminUnitKey).value?.toString(),
          ),
          AdditionalField(
            'administrativeAreaCode',
            boundary?.code,
          ),
          AdditionalField(
            'householdClientReferenceId',
            widget.householdClientReferenceId,
          ),
          AdditionalField(
            'childIndividualClientReferenceId',
            widget.childIndividualClientReferenceId,
          ),
          AdditionalField(
            AdditionalFieldsType.referredBy.toValue(),
            _form.control(_referredByKey).value?.toString(),
          ),
          AdditionalField(
            AdditionalFieldsType.nameOfReferral.toValue(),
            _selectedFacilityLabel,
          ),
          AdditionalField(
            'tbAssessmentQuestions',
            widget.screeningAnswers.join(','),
          ),
          AdditionalField(
            'tbAssessmentSymptoms',
            widget.selectedSymptomKeys.join(','),
          ),
        ],
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: userId,
        createdTime: now,
        lastModifiedBy: userId,
        lastModifiedTime: now,
      ),
      auditDetails: AuditDetails(
        createdBy: userId,
        createdTime: now,
      ),
    );

    await taskRepository.create(screeningTask);
    await referralRepository.create(referral);

    setState(() => _submitted = true);
  }

  String get _selectedFacilityLabel =>
      _selectedFacility?.name?.trim().isNotEmpty == true
          ? _selectedFacility!.name!.trim()
          : _selectedFacility?.id ?? '';

  List<String> _referralReasons() {
    final reasons = <String>[];
    for (var index = 0; index < widget.screeningAnswers.length; index++) {
      if (widget.screeningAnswers[index]) {
        reasons.add('TB_Q${index + 1}');
      }
    }
    reasons.addAll(widget.selectedSymptomKeys);
    return reasons;
  }

  Future<void> _selectFacility() async {
    final picked = await showDialog<FacilityModel>(
      context: context,
      builder: (_) => FacilityBlocWrapper(
        child: _FacilitySearchDialog(
          appLocalizations: widget.appLocalizations,
          initialSelection: _selectedFacility,
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedFacility = picked;
      _form.control(_referredToKey).value =
          picked.name?.trim().isNotEmpty == true
              ? picked.name!.trim()
              : picked.id;
      _form.control(_referredToKey).removeError('required');
    });
  }
}

class _FacilitySearchDialog extends LocalizedStatefulWidget {
  final FacilityModel? initialSelection;

  const _FacilitySearchDialog({
    super.appLocalizations,
    this.initialSelection,
  });

  @override
  State<_FacilitySearchDialog> createState() => _FacilitySearchDialogState();
}

class _FacilitySearchDialogState extends LocalizedState<_FacilitySearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(spacer2),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(spacer3),
          child: BlocBuilder<FacilityBloc, FacilityState>(
            builder: (context, state) {
              return state.maybeWhen(
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                fetched: (facilities, _) {
                  final filtered = facilities.where((facility) {
                    if (_query.trim().isEmpty) return true;
                    final query = _query.trim().toLowerCase();
                    final label =
                        '${facility.name ?? ''} ${facility.id}'.toLowerCase();
                    return label.contains(query);
                  }).toList()
                    ..sort((a, b) {
                      final aName = a.name ?? a.id;
                      final bName = b.name ?? b.id;
                      return aName.compareTo(bName);
                    });

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate(
                          i18.common.facilitySearchHeaderLabel,
                        ),
                        style: textTheme.headingM.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      DigitSearchBar(
                        controller: _searchController,
                        hintText: localizations.translate(
                          i18.searchBeneficiary.beneficiarySearchHintText,
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: spacer2),
                      Flexible(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  localizations.translate(
                                    i18.common.noResultsFound,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final facility = filtered[index];
                                  final label =
                                      facility.name?.trim().isNotEmpty == true
                                          ? facility.name!.trim()
                                          : facility.id;
                                  final subtitle =
                                      facility.name?.trim().isNotEmpty == true
                                          ? facility.id
                                          : null;
                                  final selected =
                                      widget.initialSelection?.id ==
                                          facility.id;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(label),
                                    subtitle: subtitle == null
                                        ? null
                                        : Text(subtitle),
                                    trailing: selected
                                        ? Icon(
                                            Icons.check_circle,
                                            color: theme
                                                .colorTheme.primary.primary2,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(context).pop(facility),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: spacer2),
                      DigitButton(
                        label: localizations.translate(
                          i18.common.coreCommonCancel,
                        ),
                        type: DigitButtonType.secondary,
                        size: DigitButtonSize.large,
                        mainAxisSize: MainAxisSize.max,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
