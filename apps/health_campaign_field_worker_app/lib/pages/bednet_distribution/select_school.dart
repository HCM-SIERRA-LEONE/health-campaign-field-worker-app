import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../blocs/localization/app_localization.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../utils/bednet_class_selection_singleton.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/utils.dart';
import '../../widgets/header/back_navigation_help_header.dart';

@RoutePage()
class SelectSchoolPage extends StatefulWidget {
  const SelectSchoolPage({super.key});

  @override
  State<SelectSchoolPage> createState() => _SelectSchoolPageState();
}

class _SelectSchoolPageState extends State<SelectSchoolPage> {
  static const _schoolControl = 'school';
  static const _classControl = 'class';

  static const List<String> _classOptions = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
  ];

  String? _selectedClass;

  Future<void> _checkStockAndProceed(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) async {
    final localizations = AppLocalizations.of(context);

    // Using the centralized stock count from the Singleton (updated by AuthBloc)
    final stockCount = RegistrationDeliverySingleton().stockCount;

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<BednetDistributionBloc, BednetDistributionState>(
      listenWhen: (previous, current) =>
          previous.schoolSelectionSeq != current.schoolSelectionSeq &&
          current.selectedSchool != null &&
          current.error == null,
      listener: (context, state) {
        if (!context.mounted) return;
        context.router.push(const BednetHouseholdOverviewWrapperRoute(
          children: [SchoolDetailsRoute()],
        ));
      },
      child: BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
        builder: (context, state) {
          return ReactiveFormBuilder(
            form: () => fb.group({
              _schoolControl: FormControl<HouseholdModel>(
                validators: [Validators.required],
                value: state.selectedSchool,
              ),
              _classControl: FormControl<String>(
                validators: [Validators.required],
                value: _selectedClass,
              ),
            }),
            builder: (context, form, _) {
              final theme = Theme.of(context);
              final textTheme = theme.digitTextTheme(context);
              return Scaffold(
                body: ScrollableContent(
                  enableFixedDigitButton: true,
                  header: const BackNavigationHelpHeaderWidget(
                    showHelp: false,
                  ),
                  footer: StreamBuilder<Object?>(
                    stream: form.valueChanges,
                    initialData: form.value,
                    builder: (context, _) {
                      final selected =
                          form.control(_schoolControl).value as HouseholdModel?;
                      final hasSchoolSelection = selected != null;
                      final hasClassSelection =
                          (form.control(_classControl).value as String?) != null;
                      return DigitCard(
                        margin: const EdgeInsets.only(top: spacer2),
                        children: [
                          DigitButton(
                            label: 'Next',
                            type: DigitButtonType.primary,
                            size: DigitButtonSize.large,
                            mainAxisSize: MainAxisSize.max,
                            isDisabled: state.schools.isEmpty ||
                                !hasSchoolSelection ||
                                !hasClassSelection,
                            onPressed: () {
                              form.markAllAsTouched();
                              if (!form.valid) return;
                              final school = form.control(_schoolControl).value
                                  as HouseholdModel;
                              _checkStockAndProceed(
                                context,
                                onSuccess: () {
                                  context.read<BednetDistributionBloc>().add(
                                        BednetDistributionEvent.selectSchool(
                                          school: school,
                                        ),
                                      );
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: DigitCard(
                        margin: const EdgeInsets.all(spacer2),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Select the school',
                                  style: textTheme.headingXl.copyWith(
                                    color: theme.colorTheme.primary.primary2,
                                  ),
                                ),
                              ),
                              // DigitButton(
                              //   label: 'Refresh',
                              //   type: DigitButtonType.tertiary,
                              //   size: DigitButtonSize.medium,
                              //   onPressed: () {
                              //     if (state.loading) return;
                              //     context.read<BednetDistributionBloc>().add(
                              //           const BednetDistributionEvent.reload(),
                              //         );
                              //   },
                              // ),
                            ],
                          ),
                          const SizedBox(height: spacer2),
                          ReactiveWrapperField(
                            formControlName: _schoolControl,
                            validationMessages: {
                              'required': (_) =>
                                  'Please select a school to proceed',
                            },
                            builder: (field) => LabeledField(
                              label: 'Select the school',
                              isRequired: true,
                              child: DigitDropdown<HouseholdModel>(
                                isSearchable: false,
                                items: state.schools
                                    .map(
                                      (e) => DropdownItem(
                                        name: e.bednetDisplayName,
                                        code: e.bednetSchoolId,
                                      ),
                                    )
                                    .toList(),
                                selectedOption: (form
                                            .control(_schoolControl)
                                            .value as HouseholdModel?) !=
                                        null
                                    ? DropdownItem(
                                        name: (form
                                                .control(_schoolControl)
                                                .value as HouseholdModel)
                                            .bednetDisplayName,
                                        code: (form
                                                .control(_schoolControl)
                                                .value as HouseholdModel)
                                            .bednetSchoolId,
                                      )
                                    : null,
                                onSelect: (value) {
                                  final selected = state.schools.firstWhere(
                                    (school) =>
                                        school.bednetSchoolId == value.code,
                                  );
                                  form.control(_schoolControl).value = selected;
                                },
                                errorMessage: field.errorText,
                                emptyItemText: 'No schools available',
                              ),
                            ),
                          ),
                          const SizedBox(height: spacer2),
                          ReactiveWrapperField(
                            formControlName: _classControl,
                            validationMessages: {
                              'required': (_) =>
                                  'Please select a class to proceed',
                            },
                            builder: (field) => LabeledField(
                              label: 'Select the class',
                              isRequired: true,
                              child: DigitDropdown<String>(
                                isSearchable: false,
                                items: _classOptions
                                    .map(
                                      (e) => DropdownItem(
                                        name: 'Class $e',
                                        code: e,
                                      ),
                                    )
                                    .toList(),
                                selectedOption: _selectedClass != null
                                    ? DropdownItem(
                                        name: 'Class $_selectedClass',
                                        code: _selectedClass!,
                                      )
                                    : null,
                                onSelect: (value) {
                                  setState(() {
                                    _selectedClass = value.code;
                                  });
                                  BednetClassSelectionSingleton()
                                      .setSelectedClass(
                                          selectedClass: value.code);
                                  form.control(_classControl).value =
                                      value.code;
                                },
                                errorMessage: field.errorText,
                                emptyItemText: 'No classes available',
                              ),
                            ),
                          ),
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: spacer2),
                              child: Text(
                                state.error!,
                                style: textTheme.bodyS.copyWith(
                                  color: theme.colorTheme.alert.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
