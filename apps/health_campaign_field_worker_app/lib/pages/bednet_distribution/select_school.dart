import 'package:collection/collection.dart';
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

  static final RegExp _classNameKeyPattern =
      RegExp(r'^class\d+_classname$', caseSensitive: false);

  String? _selectedClass;
  var _schoolItems = <DropdownItem>[];

  /// Extracts class names from a school's additionalFields. Supports two
  /// shapes: keys matching `class<N>_className`, or a single
  /// `className`/`classNames` field with comma-separated values. Duplicates
  /// (case-insensitive) are removed.
  List<String> _extractClassNames(HouseholdModel? school) {
    if (school == null) return const [];
    final fields = school.additionalFields?.fields ?? const <AdditionalField>[];
    final names = <String>[];
    final seen = <String>{};
    void add(String? raw) {
      final v = raw?.trim();
      if (v == null || v.isEmpty) return;
      if (seen.add(v.toLowerCase())) names.add(v);
    }

    for (final f in fields) {
      final key = f.key.toLowerCase();
      final value = (f.value as Object?)?.toString();
      if (_classNameKeyPattern.hasMatch(f.key)) {
        add(value);
      } else if (key == 'classname' || key == 'classnames') {
        if (value == null) continue;
        for (final part in value.split(',')) {
          add(part);
        }
      }
    }
    return names;
  }

  /// Returns true if [school]'s name-related additionalFields match either
  /// [dhName] or [dhCode] (case-insensitive).
  bool _matchesDhBoundary(HouseholdModel school, String dhName, String dhCode) {
    if (dhName.isEmpty && dhCode.isEmpty) return false;

    final fields = school.additionalFields?.fields ?? const <AdditionalField>[];
    final fieldMap = <String, String>{};
    for (final f in fields) {
      final v = (f.value as Object?)?.toString().trim();
      if (v != null && v.isNotEmpty) {
        fieldMap[f.key.toLowerCase()] = v.toLowerCase();
      }
    }

    final candidates = <String>{
      if (dhName.isNotEmpty) dhName.toLowerCase(),
      if (dhCode.isNotEmpty) dhCode.toLowerCase(),
    };
    final schoolNameFields = [
      fieldMap['schoolname'],
      fieldMap['school_name'],
      fieldMap['name'],
    ];
    return schoolNameFields.any((v) => v != null && candidates.contains(v));
  }

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
          final boundaryState = context.read<BoundaryBloc>().state;
          final dhBoundary =
              boundaryState.selectedBoundaryMap[Constants.dhBoundaryLevel];
          final dhName = dhBoundary?.name?.trim() ?? '';
          final dhCode = dhBoundary?.code?.trim() ?? '';
          final matchedSchool = state.schools.firstWhereOrNull(
            (s) => _matchesDhBoundary(s, dhName, dhCode),
          );
          final isPrePopulated = matchedSchool != null;

          final lastBoundary =
              boundaryState.selectedLastLevelBoundaries.firstOrNull;
          final lastBoundaryCode = lastBoundary?.code?.trim().toLowerCase();
          final lastBoundaryName = lastBoundary?.name?.trim().toLowerCase();
          final initialSchool =
              isPrePopulated ? matchedSchool : state.selectedSchool;
          final initialClassOptions = _extractClassNames(initialSchool);
          final matchedClass = initialClassOptions.firstWhereOrNull(
            (c) =>
                c.toLowerCase() == lastBoundaryCode ||
                c.toLowerCase() == lastBoundaryName,
          );
          final isPrePopulatedClass = matchedClass != null;
          final effectiveClass =
              isPrePopulatedClass ? matchedClass : _selectedClass;

          if (isPrePopulatedClass && _selectedClass != matchedClass) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _selectedClass = matchedClass;
              });
              BednetClassSelectionSingleton()
                  .setSelectedClass(selectedClass: matchedClass);
            });
          }

          // Update school items cache when schools change or on first build
          if (_schoolItems.isEmpty || _schoolItems.length != state.schools.length) {
            _schoolItems = state.schools
                .map(
                  (e) => DropdownItem(
                    name: e.bednetDisplayName,
                    code: e.bednetSchoolId,
                  ),
                )
                .toList();
          }

          // Show loading indicator only while schools are being loaded
          if (state.loading || state.schools.isEmpty) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: spacer2),
                    Text(
                      'Loading schools...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }

          return ReactiveFormBuilder(
            form: () => fb.group({
              _schoolControl: FormControl<HouseholdModel>(
                validators: [Validators.required],
                value: initialSchool,
              ),
              _classControl: FormControl<String>(
                validators: [Validators.required],
                value: effectiveClass,
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
                          (form.control(_classControl).value as String?) !=
                              null;
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
                                isDisabled: isPrePopulated,
                                items: _schoolItems,
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
                                  final previous = form
                                      .control(_schoolControl)
                                      .value as HouseholdModel?;
                                  if (previous?.bednetSchoolId !=
                                      selected.bednetSchoolId) {
                                    form.control(_classControl).value = null;
                                    setState(() {
                                      _selectedClass = null;
                                    });
                                    BednetClassSelectionSingleton()
                                        .setSelectedClass(selectedClass: null);
                                  }
                                  form.control(_schoolControl).value = selected;
                                },
                                errorMessage: field.errorText,
                                emptyItemText: 'No schools available',
                              ),
                            ),
                          ),
                          const SizedBox(height: spacer2),
                          StreamBuilder<Object?>(
                            stream: form.control(_schoolControl).valueChanges,
                            initialData: form.control(_schoolControl).value,
                            builder: (context, _) {
                              final school = form.control(_schoolControl).value
                                  as HouseholdModel?;
                              final hasSchool = school != null;
                              final classOptions = _extractClassNames(school);
                              final currentClass =
                                  form.control(_classControl).value as String?;
                              final showClassValue = currentClass != null &&
                                      classOptions.contains(currentClass)
                                  ? currentClass
                                  : null;
                              return ReactiveWrapperField(
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
                                    isDisabled: !hasSchool ||
                                        isPrePopulatedClass ||
                                        classOptions.isEmpty,
                                    items: classOptions
                                        .map(
                                          (e) => DropdownItem(
                                            name: e,
                                            code: e,
                                          ),
                                        )
                                        .toList(),
                                    selectedOption: showClassValue != null
                                        ? DropdownItem(
                                            name: showClassValue,
                                            code: showClassValue,
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
                                    emptyItemText: hasSchool
                                        ? 'No classes available'
                                        : 'Select a school first',
                                  ),
                                ),
                              );
                            },
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
