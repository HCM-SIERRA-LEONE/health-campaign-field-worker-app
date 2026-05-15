import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/household_type.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/pages/qr_scanner.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_dob_picker.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/atoms/selection_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/bednet_distribution/bednet_distribution.dart';
import 'package:health_campaign_field_worker_app/blocs/localization/app_localization.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/household_overview/household_overview.dart';
import 'package:health_campaign_field_worker_app/models/bednet_distribution/bednet_distribution_models.dart';
import 'package:health_campaign_field_worker_app/models/entities/roles_type.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/additional_fields_type.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/constants.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/i18_key_constants.dart'
    as i18;
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/utils.dart';
import 'package:health_campaign_field_worker_app/utils/utils.dart' as app_utils;
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/back_navigation_help_header.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/localized.dart';
import 'package:health_campaign_field_worker_app/widgets/registartion_deliver/showcase/showcase_wrappers.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../blocs/registration_deliver/search_households/search_households.dart';
import '../../../router/app_router.dart';
import '../../../utils/registration_deliver_utils/extensions/extensions.dart'
    hide ContextUtilityExtensions;
import '../summary_page.dart';
import 'refer_beneficiary_page.dart' show contextIsMdtUser;

@RoutePage()
class CustomIndividualDetailsPage extends LocalizedStatefulWidget {
  final bool isHeadOfHousehold;

  const CustomIndividualDetailsPage({
    super.key,
    this.isHeadOfHousehold = false,
    super.appLocalizations,
  });

  @override
  State<CustomIndividualDetailsPage> createState() =>
      CustomIndividualDetailsPageState();
}

class CustomIndividualDetailsPageState
    extends LocalizedState<CustomIndividualDetailsPage> {
  static const _individualNameKey = 'individualName';
  static const _dobKey = 'dob';
  static const _dobErrorMaxAge = 'maxAge';
  static const _genderKey = 'gender';
  static const _mobileNumberKey = 'mobileNumber';
  static const _requiredIndicator = '*';
  bool isDuplicateTag = false;
  static const maxLength = 200;
  final clickedStatus = ValueNotifier<bool>(false);
  DateTime now = DateTime.now();

  String _requiredLabel(String localizationKey) {
    return '${localizations.translate(localizationKey)} $_requiredIndicator';
  }

  /// New key each time this [State] is created (each navigation to this page).
  /// [DigitDobPicker] and other inputs keep internal state from the first
  /// [initialValue]; without this, reopening "Add student" can show the last DOB.
  final Key _pageSubtreeKey = UniqueKey();

  /// Per-screen showcase builders (each owns a new [GlobalKey]). The singleton
  /// [individualDetailsShowcaseData] reused the same keys for every route, so
  /// two [CustomIndividualDetailsPage]s in the tree briefly caused duplicate GlobalKey.
  late final ShowcaseItemBuilder _showcaseIndividualName = ShowcaseItemBuilder(
    messageLocalizationKey: i18.individualDetailsShowcase.firstNameOfIndividual,
  );
  late final ShowcaseItemBuilder _showcaseIndividualDob = ShowcaseItemBuilder(
    messageLocalizationKey: i18.individualDetailsShowcase.dateOfBirth,
  );
  late final ShowcaseItemBuilder _showcaseIndividualMobile =
      ShowcaseItemBuilder(
    messageLocalizationKey: i18.individualDetailsShowcase.mobile,
  );

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BeneficiaryRegistrationBloc>();
    final router = context.router;
    final theme = Theme.of(context);
    DateTime before150Years = DateTime(now.year - 150, now.month, now.day);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          // Navigate to view household page instead of default back behavior
          if (context.mounted) {
            await router.navigate(
              BednetHouseholdOverviewWrapperRoute(
                children: [
                  CustomHouseholdOverviewRoute(),
                ],
              ),
            );
          }
        },
        child: Scaffold(
          body: ReactiveFormBuilder(
            // New bloc instance per route push; key forces a fresh form so DOB/name
            // are not reused when opening "Add student" again from overview.
            key: ObjectKey(bloc),
            form: () => buildForm(bloc.state),
            builder: (context, form, child) => BlocConsumer<
                BeneficiaryRegistrationBloc, BeneficiaryRegistrationState>(
              listener: (context, state) {
                state.mapOrNull(
                  persisted: (value) async {
                    if (context.mounted) {
                      try {
                        context.read<BednetDistributionBloc>().add(
                              BednetDistributionEvent.updateSelectedSchool(
                                school: value.householdModel,
                              ),
                            );
                      } catch (_) {}
                    }
                    if (value.navigateToRoot) {
                      final overviewBloc =
                          context.read<HouseholdOverviewBloc>();

                      overviewBloc.add(
                        HouseholdOverviewReloadEvent(
                          projectId: RegistrationDeliverySingleton()
                              .projectId
                              .toString(),
                          projectBeneficiaryType:
                              RegistrationDeliverySingleton().beneficiaryType ??
                                  BeneficiaryType.household,
                        ),
                      );

                      await overviewBloc.stream.firstWhere((element) =>
                          element.loading == false &&
                          element.householdMemberWrapper.household != null);
                      if (!context.mounted) return;

                      // Check if this is a child registration (not head of household) and user is MDT user
                      final isChildRegistration = !value.isHeadOfHousehold &&
                          value.individualModel != null;
                      final isMdtUser = contextIsMdtUser(context);

                      if (isChildRegistration &&
                          isMdtUser &&
                          !value.householdModel.isSchoolHousehold) {
                        // Navigate to TB Assessment instead of acknowledgement screen
                        await _navigateToTBAssessment(
                          context: context,
                          child: value.individualModel!,
                          overviewBloc: overviewBloc,
                        );
                      } else {
                        // Original flow: navigate to acknowledgement screen
                        if (value.householdModel.isSchoolHousehold) {
                          await router.push(BeneficiaryAcknowledgementRoute());
                        } else {
                          await router.push(HouseholdAcknowledgementRoute());
                        }
                      }
                    } else if (!value.isEdit && value.individualModel == null) {
                      HouseholdOverviewBloc? overviewBloc;
                      try {
                        overviewBloc = context.read<HouseholdOverviewBloc>();
                      } catch (_) {
                        overviewBloc = null;
                      }
                      if (overviewBloc == null || !context.mounted) return;
                      overviewBloc.add(
                        HouseholdOverviewReloadEvent(
                          projectId: RegistrationDeliverySingleton()
                              .projectId
                              .toString(),
                          projectBeneficiaryType:
                              RegistrationDeliverySingleton().beneficiaryType ??
                                  BeneficiaryType.household,
                        ),
                      );
                      if (!context.mounted) return;
                      await router.maybePop();
                    }
                  },
                );
              },
              builder: (context, state) {
                return KeyedSubtree(
                  key: _pageSubtreeKey,
                  child: ScrollableContent(
                    enableFixedDigitButton: true,
                    header: const Column(children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: spacer2),
                        child: BackNavigationHelpHeaderWidget(
                          showHelp: false,
                        ),
                      ),
                    ]),
                    footer: DigitCard(
                        margin: const EdgeInsets.only(top: spacer2),
                        children: [
                          ValueListenableBuilder(
                            valueListenable: clickedStatus,
                            builder: (context, bool isClicked, _) {
                              return DigitButton(
                                label: state.mapOrNull(
                                      editIndividual: (value) => localizations
                                          .translate(i18.common.coreCommonSave),
                                    ) ??
                                    localizations
                                        .translate(i18.common.coreCommonSubmit),
                                type: DigitButtonType.primary,
                                size: DigitButtonSize.large,
                                mainAxisSize: MainAxisSize.max,
                                onPressed: () async {
                                  if (!widget.isHeadOfHousehold &&
                                      form.control(_dobKey).value == null) {
                                    setState(() {
                                      form
                                          .control(_dobKey)
                                          .removeError(_dobErrorMaxAge);
                                      form
                                          .control(_dobKey)
                                          .setErrors({'': true});
                                    });
                                  }
                                  // if (form.control(_idTypeKey).value == null) {
                                  //   form.control(_idTypeKey).setErrors({'': true});
                                  // }
                                  if (form.control(_genderKey).value == null) {
                                    setState(() {
                                      form
                                          .control(_genderKey)
                                          .setErrors({'': true});
                                    });
                                  }
                                  final userId = RegistrationDeliverySingleton()
                                      .loggedInUserUuid;
                                  final projectId =
                                      RegistrationDeliverySingleton().projectId;
                                  form.markAllAsTouched();
                                  if (!form.valid) return;
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  final submit = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => Popup(
                                      title: localizations.translate(
                                          i18.deliverIntervention.dialogTitle),
                                      description: localizations.translate(i18
                                          .deliverIntervention.dialogContent),
                                      actions: [
                                        DigitButton(
                                            label: localizations.translate(
                                                i18.common.coreCommonSubmit),
                                            onPressed: () {
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop(true);
                                            },
                                            type: DigitButtonType.primary,
                                            size: DigitButtonSize.large),
                                        DigitButton(
                                            label: localizations.translate(
                                                i18.common.coreCommonCancel),
                                            onPressed: () => Navigator.of(
                                                    context,
                                                    rootNavigator: true)
                                                .pop(false),
                                            type: DigitButtonType.secondary,
                                            size: DigitButtonSize.large),
                                      ],
                                    ),
                                  );
                                  if (submit ?? false) {
                                    state.maybeWhen(
                                      orElse: () {
                                        return;
                                      },
                                      create: (
                                        addressModel,
                                        householdModel,
                                        individualModel,
                                        projectBeneficiaryModel,
                                        registrationDate,
                                        searchQuery,
                                        loading,
                                        isHeadOfHousehold,
                                      ) async {
                                        final individual = _getIndividualModel(
                                          context,
                                          form: form,
                                          oldIndividual: null,
                                        );

                                        final boundary =
                                            RegistrationDeliverySingleton()
                                                .boundary;

                                        bloc.add(
                                          BeneficiaryRegistrationSaveIndividualDetailsEvent(
                                            model: individual,
                                            isHeadOfHousehold:
                                                widget.isHeadOfHousehold,
                                          ),
                                        );
                                        final scannerBloc =
                                            context.read<DigitScannerBloc>();
                                        scannerBloc.add(
                                          const DigitScannerEvent
                                              .handleScanner(),
                                        );

                                        if (scannerBloc.state.duplicate) {
                                          Toast.showToast(context,
                                              message: localizations.translate(
                                                i18.deliverIntervention
                                                    .resourceAlreadyScanned,
                                              ),
                                              type: ToastType.error);
                                        } else {
                                          clickedStatus.value = true;
                                          final scannerBloc =
                                              context.read<DigitScannerBloc>();
                                          scannerBloc.add(
                                            const DigitScannerEvent
                                                .handleScanner(),
                                          );
                                          bloc.add(
                                            BeneficiaryRegistrationSummaryEvent(
                                              projectId: projectId!,
                                              userUuid: userId!,
                                              boundary: boundary!,
                                              tag: scannerBloc
                                                      .state.qrCodes.isNotEmpty
                                                  ? scannerBloc
                                                      .state.qrCodes.first
                                                  : null,
                                            ),
                                          );
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BlocProvider.value(
                                                value: bloc,
                                                child: const SummaryPage(),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      editIndividual: (
                                        householdModel,
                                        individualModel,
                                        addressModel,
                                        projectBeneficiaryModel,
                                        loading,
                                      ) {
                                        final scannerBloc =
                                            context.read<DigitScannerBloc>();
                                        scannerBloc.add(
                                          const DigitScannerEvent
                                              .handleScanner(),
                                        );
                                        final individual = _getIndividualModel(
                                          context,
                                          form: form,
                                          oldIndividual: individualModel,
                                        );
                                        final tag = scannerBloc
                                                .state.qrCodes.isNotEmpty
                                            ? scannerBloc.state.qrCodes.first
                                            : null;

                                        if (tag != null &&
                                            tag !=
                                                projectBeneficiaryModel?.tag &&
                                            scannerBloc.state.duplicate) {
                                          Toast.showToast(context,
                                              message: localizations.translate(
                                                i18.deliverIntervention
                                                    .resourceAlreadyScanned,
                                              ),
                                              type: ToastType.error);
                                        } else {
                                          bloc.add(
                                            BeneficiaryRegistrationUpdateIndividualDetailsEvent(
                                              addressModel: addressModel,
                                              householdModel: householdModel,
                                              model: individual.copyWith(
                                                clientAuditDetails: (individual
                                                                .clientAuditDetails
                                                                ?.createdBy !=
                                                            null &&
                                                        individual
                                                                .clientAuditDetails
                                                                ?.createdTime !=
                                                            null)
                                                    ? ClientAuditDetails(
                                                        createdBy: individual
                                                            .clientAuditDetails!
                                                            .createdBy,
                                                        createdTime: individual
                                                            .clientAuditDetails!
                                                            .createdTime,
                                                        lastModifiedBy:
                                                            RegistrationDeliverySingleton()
                                                                .loggedInUserUuid,
                                                        lastModifiedTime: context
                                                            .millisecondsSinceEpoch(),
                                                      )
                                                    : null,
                                              ),
                                              tag: scannerBloc
                                                      .state.qrCodes.isNotEmpty
                                                  ? scannerBloc
                                                      .state.qrCodes.first
                                                  : null,
                                            ),
                                          );
                                        }
                                      },
                                      addMember: (
                                        addressModel,
                                        householdModel,
                                        loading,
                                        isHeadFromState,
                                      ) {
                                        final individual = _getIndividualModel(
                                          context,
                                          form: form,
                                        );

                                        if (context.mounted) {
                                          final scannerBloc =
                                              context.read<DigitScannerBloc>();
                                          scannerBloc.add(
                                            const DigitScannerEvent
                                                .handleScanner(),
                                          );
                                          if (scannerBloc.state.duplicate) {
                                            Toast.showToast(
                                              context,
                                              message: localizations.translate(
                                                i18.deliverIntervention
                                                    .resourceAlreadyScanned,
                                              ),
                                              type: ToastType.error,
                                            );
                                          } else {
                                            bloc.add(
                                              BeneficiaryRegistrationAddMemberEvent(
                                                beneficiaryType:
                                                    RegistrationDeliverySingleton()
                                                        .beneficiaryType!,
                                                householdModel: householdModel,
                                                individualModel: individual,
                                                addressModel: addressModel,
                                                userUuid:
                                                    RegistrationDeliverySingleton()
                                                        .loggedInUserUuid!,
                                                projectId:
                                                    RegistrationDeliverySingleton()
                                                        .projectId!,
                                                tag: scannerBloc.state.qrCodes
                                                        .isNotEmpty
                                                    ? scannerBloc
                                                        .state.qrCodes.first
                                                    : null,
                                                isHeadOfHousehold:
                                                    isHeadFromState ||
                                                        widget
                                                            .isHeadOfHousehold,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ]),
                    slivers: [
                      SliverToBoxAdapter(
                        child: DigitCard(
                            margin: const EdgeInsets.all(spacer2),
                            children: [
                              Text(
                                localizations.translate(
                                  i18.individualDetails
                                      .individualsDetailsLabelText,
                                ),
                                style: textTheme.headingXl.copyWith(
                                    color: theme.colorTheme.primary.primary2),
                              ),
                              Column(
                                children: [
                                  _showcaseIndividualName.buildWith(
                                    child: ReactiveWrapperField(
                                      formControlName: _individualNameKey,
                                      validationMessages: {
                                        'required': (object) =>
                                            localizations.translate(
                                              '${i18.individualDetails.nameLabelText}_IS_REQUIRED',
                                            ),
                                        'maxLength': (object) => localizations
                                            .translate(
                                                i18.common.maxCharsRequired)
                                            .replaceAll(
                                                '{}', maxLength.toString()),
                                      },
                                      builder: (field) => LabeledField(
                                        label: localizations.translate(
                                          i18.individualDetails.nameLabelText,
                                        ),
                                        isRequired: true,
                                        child: DigitTextFormInput(
                                          initialValue: form
                                              .control(_individualNameKey)
                                              .value,
                                          onChange: (value) {
                                            form
                                                .control(_individualNameKey)
                                                .value = value;
                                          },
                                          errorMessage: field.errorText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.isHeadOfHousehold)
                                    const SizedBox(
                                      height: spacer2,
                                    ),
                                  Offstage(
                                    offstage: !widget.isHeadOfHousehold,
                                    child: DigitCheckbox(
                                      capitalizeFirstLetter: false,
                                      label: (RegistrationDeliverySingleton()
                                                  .householdType ==
                                              HouseholdType.community)
                                          ? localizations.translate(i18
                                              .individualDetails
                                              .clfCheckboxLabelText)
                                          : "School Head",
                                      value: widget.isHeadOfHousehold,
                                      readOnly: widget.isHeadOfHousehold,
                                      onChanged: (_) {},
                                    ),
                                  ),
                                ],
                              ),
                              _showcaseIndividualDob.buildWith(
                                child: DigitDobPicker(
                                  datePickerFormControl: _dobKey,
                                  datePickerLabel: _requiredLabel(
                                      i18.individualDetails.dobLabelText),
                                  ageFieldLabel: _requiredLabel(
                                      i18.individualDetails.ageLabelText),
                                  yearsHintLabel: localizations.translate(
                                    i18.individualDetails.yearsHintText,
                                  ),
                                  monthsHintLabel: localizations.translate(
                                    i18.individualDetails.monthsHintText,
                                  ),
                                  separatorLabel: localizations.translate(
                                    i18.individualDetails.separatorLabelText,
                                  ),
                                  yearsAndMonthsErrMsg: localizations.translate(
                                    i18.individualDetails
                                        .yearsAndMonthsErrorText,
                                  ),
                                  errorMessage: () {
                                    final dobControl = form.control(_dobKey);
                                    if (!dobControl.hasErrors) return null;
                                    if (dobControl.hasError(_dobErrorMaxAge) &&
                                        !widget.isHeadOfHousehold) {
                                      // return localizations.translate(
                                      //   i18.individualDetails
                                      //       .maxBeneficiaryAgeAllowedMessage,
                                      // );
                                      return "Age cannot be greater than 14 years.";
                                    }
                                    return localizations.translate(
                                        i18.common.corecommonRequired);
                                  }(),
                                  initialDate: before150Years,
                                  initialValue: getInitialDateValue(form),
                                  onChangeOfFormControl: (value) {
                                    setState(() {
                                      final dobControl = form.control(_dobKey);
                                      if (value == null) {
                                        dobControl.removeError(_dobErrorMaxAge);
                                        dobControl.setErrors({'': true});
                                      } else {
                                        DigitDOBAgeConvertor age =
                                            DigitDateUtils.calculateAge(value);
                                        if (age.years > 14 && age.months >= 0) {
                                          dobControl.removeError('');
                                          dobControl.setErrors(
                                              {_dobErrorMaxAge: true});
                                        } else if ((age.years == 0 &&
                                                age.months == 0) ||
                                            (age.months > 11)) {
                                          dobControl
                                              .removeError(_dobErrorMaxAge);
                                          dobControl.setErrors({'': true});
                                        } else {
                                          dobControl.value = value;
                                          dobControl.removeError('');
                                          dobControl
                                              .removeError(_dobErrorMaxAge);
                                        }
                                      }
                                    });
                                    // Handle changes to the control's value here
                                  },
                                  cancelText: localizations
                                      .translate(i18.common.coreCommonCancel),
                                  confirmText: localizations
                                      .translate(i18.common.coreCommonOk),
                                ),
                              ),
                              SelectionCard<String>(
                                isRequired: true,
                                showParentContainer: true,
                                title: localizations.translate(
                                  i18.individualDetails.genderLabelText,
                                ),
                                allowMultipleSelection: false,
                                width: 126,
                                initialSelection:
                                    form.control(_genderKey).value != null
                                        ? [form.control(_genderKey).value]
                                        : [],
                                options: RegistrationDeliverySingleton()
                                    .genderOptions!
                                    .map(
                                      (e) => e,
                                    )
                                    .toList(),
                                onSelectionChanged: (value) {
                                  setState(() {
                                    if (value.isNotEmpty) {
                                      form.control(_genderKey).value =
                                          value.first;
                                    } else {
                                      form.control(_genderKey).value = null;
                                      setState(() {
                                        form
                                            .control(_genderKey)
                                            .setErrors({'': true});
                                      });
                                    }
                                  });
                                },
                                valueMapper: (value) {
                                  return localizations.translate(value);
                                },
                                errorMessage: form.control(_genderKey).hasErrors
                                    ? localizations.translate(
                                        i18.common.corecommonRequired)
                                    : null,
                              ),
                              if (widget.isHeadOfHousehold)
                                _showcaseIndividualMobile.buildWith(
                                  child: ReactiveWrapperField(
                                    formControlName: _mobileNumberKey,
                                    validationMessages: {
                                      'maxLength': (object) =>
                                          localizations.translate(i18
                                              .individualDetails
                                              .mobileNumberLengthValidationMessage),
                                      'minLength': (object) =>
                                          localizations.translate(i18
                                              .individualDetails
                                              .mobileNumberLengthValidationMessage),
                                    },
                                    builder: (field) => LabeledField(
                                      label: localizations.translate(
                                        i18.individualDetails
                                            .mobileNumberLabelText,
                                      ),
                                      child: DigitTextFormInput(
                                        keyboardType: TextInputType.number,
                                        maxLength: 11,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        initialValue: form
                                            .control(_mobileNumberKey)
                                            .value,
                                        onChange: (value) {
                                          form.control(_mobileNumberKey).value =
                                              value;
                                        },
                                        errorMessage: field.errorText,
                                      ),
                                    ),
                                  ),
                                ),
                            ]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ));
  }

  IndividualModel _getIndividualModel(
    BuildContext context, {
    required FormGroup form,
    IndividualModel? oldIndividual,
  }) {
    final dob = form.control(_dobKey).value as DateTime?;
    String? dobString;
    if (dob != null) {
      dobString = DateFormat(Constants().dateFormat).format(dob);
    }

    var individual = oldIndividual;
    individual ??= IndividualModel(
      clientReferenceId: IdGen.i.identifier,
      tenantId: RegistrationDeliverySingleton().tenantId,
      rowVersion: 1,
      auditDetails: AuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
    );

    var name = individual.name;
    name ??= NameModel(
      individualClientReferenceId: individual.clientReferenceId,
      tenantId: RegistrationDeliverySingleton().tenantId,
      rowVersion: 1,
      auditDetails: AuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
    );

    var identifier = (individual.identifiers?.isNotEmpty ?? false)
        ? individual.identifiers!.first
        : null;

    identifier ??= IdentifierModel(
      clientReferenceId: individual.clientReferenceId,
      tenantId: RegistrationDeliverySingleton().tenantId,
      rowVersion: 1,
      auditDetails: AuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
      clientAuditDetails: ClientAuditDetails(
        createdBy: RegistrationDeliverySingleton().loggedInUserUuid!,
        createdTime: context.millisecondsSinceEpoch(),
        lastModifiedBy: RegistrationDeliverySingleton().loggedInUserUuid,
        lastModifiedTime: context.millisecondsSinceEpoch(),
      ),
      individualClientReferenceId: individual.clientReferenceId,
    );

    String? individualName = form.control(_individualNameKey).value as String?;
    individual = individual.copyWith(
      name: name.copyWith(
        givenName: individualName?.trim(),
      ),
      gender: form.control(_genderKey).value == null
          ? null
          : Gender.values
              .byName(form.control(_genderKey).value.toString().toLowerCase()),
      mobileNumber: form.control(_mobileNumberKey).value,
      dateOfBirth: dobString,
      // identifiers: [
      //   identifier.copyWith(
      //     identifierId: form.control(_idNumberKey).value ?? 'test',
      //     identifierType: form.control(_idTypeKey).value ?? 'test',
      //   ),
      // ],
    );

    return individual;
  }

  FormGroup buildForm(BeneficiaryRegistrationState state) {
    final individual = state.mapOrNull<IndividualModel>(
      editIndividual: (value) {
        if (value.projectBeneficiaryModel?.tag != null) {
          context.read<DigitScannerBloc>().add(DigitScannerScanEvent(
              barCode: [], qrCode: [value.projectBeneficiaryModel!.tag!]));
        }

        return value.individualModel;
      },
      create: (value) {
        return value.individualModel;
      },
      summary: (value) {
        return value.individualModel;
      },
      addMember: (_) => null,
    );

    final searchQuery = state.mapOrNull<String>(
      create: (value) {
        return value.searchQuery;
      },
    );

    return fb.group(<String, Object>{
      _individualNameKey: FormControl<String>(
        validators: [
          Validators.required,
          Validators.delegate(
              (validator) => CustomValidator.requiredMin(validator)),
          Validators.maxLength(200),
        ],
        value: individual?.name?.givenName ??
            ((RegistrationDeliverySingleton().householdType ==
                    HouseholdType.community)
                ? null
                : searchQuery?.trim()),
      ),
      _dobKey: FormControl<DateTime>(
          value: individual?.dateOfBirth != null
              ? DateFormat(Constants().dateFormat).parse(
                  individual!.dateOfBirth!,
                )
              : null,
          validators: []),
      _genderKey: FormControl<String>(value: getGenderOptions(individual)),
      _mobileNumberKey:
          FormControl<String>(value: individual?.mobileNumber, validators: [
        Validators.pattern(Constants.mobileNumberRegExp,
            validationMessage:
                localizations.translate(i18.common.coreCommonMobileNumber)),
        Validators.maxLength(11)
      ]),
    });
  }

  getGenderOptions(IndividualModel? individual) {
    final options = RegistrationDeliverySingleton().genderOptions;

    return options?.map((e) => e).firstWhereOrNull(
          (element) => element.toLowerCase() == individual?.gender?.name,
        );
  }

  getInitialDateValue(FormGroup form) {
    var date = form.control(_dobKey).value != null
        ? DateFormat(Constants().dateTimeExtFormat)
            .format(form.control(_dobKey).value)
        : null;

    return date;
  }

  /// Navigate to TB Assessment (BeneficiaryChecklistRoute) for the newly created child
  Future<void> _navigateToTBAssessment({
    required BuildContext context,
    required IndividualModel child,
    required HouseholdOverviewBloc overviewBloc,
  }) async {
    // Check stock before proceeding
    await _checkStockAndProceed(
      context,
      onSuccess: () async {
        // Get the project beneficiary client reference ID from the overview state
        final wrapper = overviewBloc.state.householdMemberWrapper;
        final pbId = wrapper.projectBeneficiaries
            ?.firstWhereOrNull(
              (b) => b.beneficiaryClientReferenceId == child.clientReferenceId,
            )
            ?.clientReferenceId;

        if (pbId == null || pbId.isEmpty) {
          // If we can't find the project beneficiary ID, fall back to acknowledgement
          if (context.mounted) {
            await context.router.push(HouseholdAcknowledgementRoute());
          }
          return;
        }

        final householdId = wrapper.household?.clientReferenceId ?? '';

        final areaCode =
            wrapper.headOfHousehold?.address?.first.locality?.code ??
                RegistrationDeliverySingleton().boundary?.code ??
                '';

        if (context.mounted) {
          await context.router.push<void>(
            BeneficiaryChecklistRoute(
              beneficiaryClientRefId: child.clientReferenceId,
              projectBeneficiaryClientRefId: pbId,
              householdClientReferenceId: householdId,
              administrativeAreaCode: areaCode,
              screeningIndividual: child,
              appLocalizations: localizations,
              isChildRegistrationLoop: true,
              householdClientRefIdForLoop: householdId,
            ),
          );
        }
      },
    );
  }

  /// Check stock availability before proceeding with TB Assessment
  Future<void> _checkStockAndProceed(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) async {
    final localizations = AppLocalizations.of(context);

    // Using the centralized stock count from the Singleton (updated by AuthBloc)
    final stockCount = app_utils.RegistrationDeliverySingleton().stockCount;

    // If stock is specifically 0 (or less), show the blocking popup.
    // If it's null, we allow proceeding as the count might not be initialized yet.
    if (stockCount != null && stockCount <= 0) {
      showCustomPopup(
        context: context,
        builder: (popupContext) => Popup(
          title: localizations
              .translate(i18.beneficiaryDetails.insufficientStockHeading),
          onOutsideTap: () {
            Navigator.of(popupContext).pop(false);
          },
          description: localizations.translate(
            i18.beneficiaryDetails.insufficientStockDescription,
          ),
          type: PopUpType.simple,
          actions: [
            DigitButton(
              label: localizations.translate(i18.beneficiaryDetails.goToHome),
              onPressed: () {
                Navigator.of(
                  popupContext,
                  rootNavigator: true,
                ).pop();
                context.router.replaceAll([HomeRoute()]);
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
}
