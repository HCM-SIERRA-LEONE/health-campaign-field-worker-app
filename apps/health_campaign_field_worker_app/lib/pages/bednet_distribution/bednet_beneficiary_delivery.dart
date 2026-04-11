import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/panel_cards.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../blocs/registration_deliver/search_households/search_households.dart';
import '../../models/entities/additional_fields_type.dart';
import '../../models/registration_deliver_model/entities/status.dart';
import '../../utils/i18_key_constants.dart' as app_i18;
import '../../utils/registration_deliver_utils/constants.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_household_session.dart';

enum _BednetDeliveryStep { details, recordDetails, success }

class BednetBeneficiaryDeliveryPage extends LocalizedStatefulWidget {
  final HouseholdMemberWrapper householdMember;
  final IndividualModel beneficiary;
  final VoidCallback onBackToSchoolSelection;
  final void Function(TaskModel task) onDeliveryRecorded;

  const BednetBeneficiaryDeliveryPage({
    super.key,
    super.appLocalizations,
    required this.householdMember,
    required this.beneficiary,
    required this.onBackToSchoolSelection,
    required this.onDeliveryRecorded,
  });

  @override
  State<BednetBeneficiaryDeliveryPage> createState() =>
      _BednetBeneficiaryDeliveryPageState();
}

class _ResolvedResource {
  const _ResolvedResource({
    required this.productVariantId,
    required this.name,
    required this.quantity,
  });

  final String productVariantId;
  final String name;
  final int quantity;
}

class _BednetBeneficiaryDeliveryPageState
    extends LocalizedState<BednetBeneficiaryDeliveryPage> {
  static const Color _headerColor = Color(0xFF202124);
  static const Color _tableBorderColor = Color(0xFFD9D9D9);
  static const Color _tableRowFill = Color(0xFFF3D9CA);

  _BednetDeliveryStep _step = _BednetDeliveryStep.details;
  bool _isSubmitting = false;
  int _quantityDistributed = 1;

  ProjectBeneficiaryModel? get _projectBeneficiary =>
      widget.householdMember.projectBeneficiaries?.firstWhereOrNull(
        (element) =>
            element.beneficiaryClientReferenceId ==
            widget.beneficiary.clientReferenceId,
      );

  List<TaskModel> get _beneficiaryTasks => (widget.householdMember.tasks ?? [])
      .where(
        (task) =>
            task.projectBeneficiaryClientReferenceId ==
            _projectBeneficiary?.clientReferenceId,
      )
      .toList();

  _ResolvedResource? get _resource {
    final currentCycle =
        RegistrationDeliverySingleton().projectType?.cycles?.firstWhereOrNull(
              (cycle) =>
                  cycle.startDate < DateTime.now().millisecondsSinceEpoch &&
                  cycle.endDate > DateTime.now().millisecondsSinceEpoch,
            );
    final cycleDelivery = currentCycle?.deliveries?.firstOrNull;
    final cycleResource =
        cycleDelivery?.doseCriteria?.firstOrNull?.productVariants?.firstOrNull;

    if (cycleResource != null) {
      return _ResolvedResource(
        productVariantId: cycleResource.productVariantId,
        name: cycleResource.name,
        quantity: cycleResource.quantity ?? 1,
      );
    }

    final projectResource =
        RegistrationDeliverySingleton().projectType?.resources?.firstOrNull;
    if (projectResource != null) {
      return _ResolvedResource(
        productVariantId: projectResource.productVariantId,
        name: projectResource.name ?? 'Bednet',
        quantity: 1,
      );
    }

    return null;
  }

  int get _currentCycleId {
    return RegistrationDeliverySingleton()
            .projectType
            ?.cycles
            ?.firstWhereOrNull(
              (cycle) =>
                  cycle.startDate < DateTime.now().millisecondsSinceEpoch &&
                  cycle.endDate > DateTime.now().millisecondsSinceEpoch,
            )
            ?.id ??
        1;
  }

  String get _currentCycleToken => '0$_currentCycleId';

  bool get _alreadyDeliveredThisRound => _beneficiaryTasks.any((task) {
        final cycleIndex = task.additionalFields?.fields
            .firstWhereOrNull(
              (field) => field.key == AdditionalFieldsType.cycleIndex.toValue(),
            )
            ?.value
            ?.toString();
        final status = task.status;
        return cycleIndex == _currentCycleToken &&
            (status == Status.administeredSuccess.toValue() ||
                status == Status.delivered.toValue());
      });

  String _formatDate(int? millis) {
    if (millis == null) return '--';
    return DateFormat(Constants().dateMonthYearFormat)
        .format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  String _nameOf(IndividualModel individual) {
    return [
      individual.name?.givenName,
      individual.name?.familyName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
  }

  String _genderOf(IndividualModel individual) {
    final gender = individual.gender?.name;
    if (gender == null || gender.isEmpty) return '--';
    return localizations.translate('CORE_COMMON_${gender.toUpperCase()}');
  }

  String _ageOf(IndividualModel individual) {
    final dob = individual.dateOfBirth;
    if (dob == null || dob.trim().isEmpty) return '--';
    final parsed = DigitDateUtils.getFormattedDateToDateTime(dob.trim());
    if (parsed == null) return '--';
    final age = DigitDateUtils.calculateAge(parsed);
    return '${age.years} ${localizations.translate(i18.searchBeneficiary.yearsAbbr)} '
        '${age.months} ${localizations.translate(i18.searchBeneficiary.monthsAbbr)}';
  }

  Future<void> _openResourceDialog() async {
    final resource = _resource;
    if (resource == null || _projectBeneficiary == null) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations
            .translate(i18.beneficiaryDetails.resourcesTobeDelivered),
        actions: [
          DigitButton(
            label: localizations.translate(i18.beneficiaryDetails.ctaProceed),
            onPressed: () => Navigator.of(ctx).pop(true),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ],
        additionalWidgets: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _tableBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(spacer2),
                  child: Text(
                    localizations.translate(
                      i18.deliverIntervention.resourceHeaderLabel,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(spacer2),
                  child: Text('${resource.quantity} ${resource.name}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      setState(() {
        _quantityDistributed = resource.quantity;
        _step = _BednetDeliveryStep.recordDetails;
      });
    }
  }

  Future<void> _submitDelivery() async {
    if (_projectBeneficiary == null || _resource == null) return;
    if (_quantityDistributed <= 0 ||
        _alreadyDeliveredThisRound ||
        _isSubmitting) {
      return;
    }

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Popup(
        title: localizations.translate(i18.deliverIntervention.dialogTitle),
        description:
            localizations.translate(i18.deliverIntervention.dialogContent),
        actions: [
          DigitButton(
            label: localizations.translate(i18.common.coreCommonSubmit),
            onPressed: () => Navigator.of(ctx).pop(true),
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
          DigitButton(
            label: localizations.translate(i18.common.coreCommonCancel),
            onPressed: () => Navigator.of(ctx).pop(false),
            type: DigitButtonType.secondary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );

    if (submit != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final taskRepository =
          context.repository<TaskModel, TaskSearchModel>(context);
      final taskClientReferenceId = IdGen.i.identifier;
      final now = context.millisecondsSinceEpoch();
      final boundary = RegistrationDeliverySingleton().boundary;
      final locality = boundary?.code != null && boundary?.name != null
          ? LocalityModel(code: boundary!.code!, name: boundary.name!)
          : null;

      final task = TaskModel(
        projectBeneficiaryClientReferenceId:
            _projectBeneficiary!.clientReferenceId,
        clientReferenceId: taskClientReferenceId,
        projectId: RegistrationDeliverySingleton().projectId,
        tenantId: RegistrationDeliverySingleton().tenantId,
        rowVersion: 1,
        status: Status.administeredSuccess.toValue(),
        address: widget.beneficiary.address?.firstOrNull?.copyWith(
              relatedClientReferenceId: taskClientReferenceId,
              locality: locality,
              id: null,
            ) ??
            widget.householdMember.household?.address?.copyWith(
              relatedClientReferenceId: taskClientReferenceId,
              locality: locality,
              id: null,
            ),
        resources: [
          TaskResourceModel(
            taskclientReferenceId: taskClientReferenceId,
            clientReferenceId: IdGen.i.identifier,
            productVariantId: _resource!.productVariantId,
            isDelivered: true,
            quantity: _quantityDistributed.toString(),
            tenantId: RegistrationDeliverySingleton().tenantId,
            rowVersion: 1,
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
          ),
        ],
        additionalFields: TaskAdditionalFields(
          version: 1,
          fields: [
            AdditionalField('taskStatus', Status.administeredSuccess.toValue()),
            AdditionalField(
              AdditionalFieldsType.dateOfDelivery.toValue(),
              now.toString(),
            ),
            AdditionalField(
              AdditionalFieldsType.dateOfAdministration.toValue(),
              now.toString(),
            ),
            AdditionalField(
              AdditionalFieldsType.dateOfVerification.toValue(),
              now.toString(),
            ),
            AdditionalField(
              AdditionalFieldsType.cycleIndex.toValue(),
              _currentCycleToken,
            ),
            const AdditionalField(
              'doseIndex',
              '01',
            ),
            const AdditionalField(
              'deliveryStrategy',
              'DIRECT',
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

      await taskRepository.create(task);
      BednetHouseholdSession.markItnDelivered();
      widget.onDeliveryRecorded(task);

      if (mounted) {
        setState(() {
          _step = _BednetDeliveryStep.success;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: spacer1),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, TextStyle style) {
    return Text(
      label,
      style: style.copyWith(
        color: _headerColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildBeneficiaryDetailsScreen() {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const Column(
          children: [
            BackNavigationHelpHeaderWidget(showHelp: false),
          ],
        ),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label:
                  localizations.translate(app_i18.studentsList.recordDelivery),
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              isDisabled:
                  _alreadyDeliveredThisRound || _projectBeneficiary == null,
              onPressed: _openResourceDialog,
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
                      _sectionTitle(
                        localizations.translate(
                          i18.beneficiaryDetails.beneficiarysDetailsLabelText,
                        ),
                        textTheme.headingXl,
                      ),
                      const SizedBox(height: spacer2),
                      _labelValue(
                        localizations.translate(i18.common.coreCommonName),
                        _nameOf(widget.beneficiary),
                      ),
                      _labelValue(
                        localizations.translate(i18.common.coreCommonAge),
                        _ageOf(widget.beneficiary),
                      ),
                      _labelValue(
                        localizations.translate(i18.common.coreCommonGender),
                        _genderOf(widget.beneficiary),
                      ),
                      _labelValue(
                        localizations.translate(
                          i18.householdDetails.dateOfRegistrationLabel,
                        ),
                        _formatDate(_projectBeneficiary?.dateOfRegistration),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      _sectionTitle(
                        localizations.translate(
                          i18.beneficiaryDetails.currentRoundLabel,
                        ),
                        textTheme.headingL,
                      ),
                      const SizedBox(height: spacer2),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.4),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.2),
                        },
                        border: TableBorder.all(color: _tableBorderColor),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Colors.white),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text(
                                  localizations.translate(
                                    i18.beneficiaryDetails.deliveryNoLabel,
                                  ),
                                  style: textTheme.bodyS
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text(
                                  localizations.translate(
                                    i18.beneficiaryDetails.beneficiaryStatus,
                                  ),
                                  style: textTheme.bodyS
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text(
                                  localizations.translate(
                                    i18.beneficiaryDetails.completedOnLabel,
                                  ),
                                  style: textTheme.bodyS
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          TableRow(
                            decoration:
                                const BoxDecoration(color: _tableRowFill),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text('Delivery $_currentCycleId'),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text(
                                  _alreadyDeliveredThisRound
                                      ? localizations.translate(
                                          i18.householdDetails.deliveredLabel,
                                        )
                                      : localizations.translate(
                                          i18.beneficiaryDetails.toDeliverLabel,
                                        ),
                                  style: textTheme.bodyS
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(spacer2),
                                child: Text(
                                  _alreadyDeliveredThisRound
                                      ? _formatDate(
                                          _beneficiaryTasks.lastOrNull
                                              ?.clientAuditDetails?.createdTime,
                                        )
                                      : '--',
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildRecordDetailsScreen() {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: Column(
          children: [
            BackNavigationHelpHeaderWidget(
              showHelp: false,
              handleBack: () {
                setState(() => _step = _BednetDeliveryStep.details);
              },
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
              isDisabled: _isSubmitting ||
                  _quantityDistributed <= 0 ||
                  _alreadyDeliveredThisRound,
              onPressed: _submitDelivery,
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
                      _sectionTitle(
                        localizations.translate(
                          i18.deliverIntervention.recordDeliveryDetailsLabel,
                        ),
                        textTheme.headingXl,
                      ),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      _sectionTitle(
                        localizations.translate(
                          i18.deliverIntervention
                              .deliverInterventionResourceLabel,
                        ),
                        textTheme.headingL,
                      ),
                      const SizedBox(height: spacer2),
                      Text(
                        localizations.translate(
                          i18.deliverIntervention.selectResourceDeliveredLabel,
                        ),
                      ),
                      const SizedBox(height: spacer1),
                      InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: spacer2,
                            vertical: spacer2,
                          ),
                        ),
                        child: Text(
                          '${_resource?.quantity ?? 1} ${_resource?.name ?? 'Bednet'}',
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      Text(
                        localizations.translate(
                          i18.deliverIntervention.quantityDistributedLabel,
                        ),
                      ),
                      const SizedBox(height: spacer1),
                      DigitNumericFormInput(
                        minValue: 1,
                        step: 1,
                        initialValue: _quantityDistributed.toString(),
                        onChange: (value) {
                          setState(() {
                            _quantityDistributed = int.tryParse(value) ?? 1;
                          });
                        },
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

  Widget _buildSuccessScreen() {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
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
                const SizedBox(height: spacer3),
                DigitButton(
                  label: localizations.translate(
                    i18.deliverIntervention.viewSchoolDetails,
                  ),
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: spacer2),
                DigitButton(
                  label: localizations.translate(
                    i18.deliverIntervention.backToSchoolSelection,
                  ),
                  type: DigitButtonType.secondary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  onPressed: widget.onBackToSchoolSelection,
                ),
                const Spacer(),
                Text(
                  _alreadyDeliveredThisRound
                      ? localizations
                          .translate(i18.householdDetails.deliveredLabel)
                      : '',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyS.copyWith(
                    color: theme.colorTheme.text.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _BednetDeliveryStep.details:
        return _buildBeneficiaryDetailsScreen();
      case _BednetDeliveryStep.recordDetails:
        return _buildRecordDetailsScreen();
      case _BednetDeliveryStep.success:
        return _buildSuccessScreen();
    }
  }
}
