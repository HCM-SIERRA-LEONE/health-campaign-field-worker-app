import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../router/app_router.dart';
import '../widgets/header/back_navigation_help_header.dart';

Map<String, dynamic>? _headTeacherNameValidator(
  AbstractControl<dynamic> control,
) {
  final raw = control.value?.toString() ?? '';
  final t = raw.trim();
  if (t.isEmpty) return {'required': true};
  if (t.length < 3) return {'minLength': true};
  if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(t)) {
    return {'alphabetOnly': true};
  }
  return null;
}

Map<String, dynamic>? _mobileElevenDigits(
  AbstractControl<dynamic> control,
) {
  final raw = control.value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length != 11) {
    return {'mobileElevenDigits': true};
  }
  return null;
}

@RoutePage()
class HouseholdHeadTeacherDetailsPage extends StatelessWidget {
  const HouseholdHeadTeacherDetailsPage({super.key});

  static const _name = 'name';
  static const _isHeadTeacher = 'isHeadTeacher';
  static const _gender = 'gender';
  static const _mobile = 'mobile';

  static const _genderItems = [
    DropdownItem(name: 'Male', code: 'Male'),
    DropdownItem(name: 'Female', code: 'Female'),
  ];

  static String _digitsOnly(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    return ReactiveFormBuilder(
      form: () => fb.group({
        _name: FormControl<String>(
          value: '',
          validators: [Validators.delegate(_headTeacherNameValidator)],
        ),
        _isHeadTeacher: FormControl<bool>(
          value: false,
          validators: [Validators.requiredTrue],
        ),
        _gender: FormControl<String>(
          value: 'Male',
          validators: [Validators.required],
        ),
        _mobile: FormControl<String>(
          value: '',
          validators: [Validators.delegate(_mobileElevenDigits)],
        ),
      }),
      builder: (context, form, _) {
        final theme = Theme.of(context);
        final textTheme = theme.digitTextTheme(context);

        return Scaffold(
          body: ScrollableContent(
            enableFixedDigitButton: true,
            header: const BackNavigationHelpHeaderWidget(showHelp: false),
            footer: StreamBuilder<Object?>(
              stream: form.valueChanges,
              initialData: form.value,
              builder: (context, _) {
                return DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    DigitButton(
                      label: 'Submit',
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      isDisabled: !form.valid,
                      onPressed: () {
                        form.markAllAsTouched();
                        if (!form.valid) return;
                        context.router.maybePop();
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
                    Text(
                      'Head Teacher Details',
                      style: textTheme.headingXl.copyWith(
                        color: theme.colorTheme.primary.primary2,
                      ),
                    ),
                    const SizedBox(height: spacer3),
                    ReactiveWrapperField(
                      formControlName: _name,
                      validationMessages: {
                        'required': (_) => 'Name of the individual is required',
                        'minLength': (_) =>
                            'Name of the individual must be at least 3 characters',
                        'alphabetOnly': (_) =>
                            'Name of the individual may only contain letters',
                      },
                      builder: (field) => LabeledField(
                        label: 'Name of the individual',
                        isRequired: true,
                        child: DigitTextFormInput(
                          initialValue: form.control(_name).value,
                          errorMessage: field.errorText,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z ]'),
                            ),
                          ],
                          onChange: (value) {
                            form.control(_name).value = value;
                          },
                        ),
                      ),
                    ),
                    ReactiveWrapperField(
                      formControlName: _isHeadTeacher,
                      validationMessages: {
                        ValidationMessage.requiredTrue: (_) =>
                            'Please confirm head teacher',
                      },
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DigitCheckbox(
                                value:
                                    (form.control(_isHeadTeacher).value as bool?) ??
                                        false,
                                onChanged: (val) {
                                  form.control(_isHeadTeacher).value = val;
                                },
                              ),
                              const SizedBox(width: spacer1),
                              Text(
                                'Head Teacher',
                                style: textTheme.bodyL,
                              ),
                            ],
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: spacer1),
                              child: Text(
                                field.errorText!,
                                style: textTheme.bodyS.copyWith(
                                  color: theme.colorTheme.alert.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    LabeledField(
                      label: 'Gender',
                      isRequired: true,
                      child: ReactiveDropdownField<String>(
                        formControlName: _gender,
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Gender is required',
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: spacer2,
                            vertical: spacer1,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(spacer1),
                          ),
                          errorMaxLines: 2,
                        ),
                        isExpanded: true,
                        items: _genderItems
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e.code,
                                child: Text(e.name),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ReactiveWrapperField(
                      formControlName: _mobile,
                      validationMessages: {
                        'mobileElevenDigits': (_) =>
                            'Enter exactly 11 digits for mobile number',
                      },
                      builder: (field) => LabeledField(
                        label: 'Mobile number',
                        child: DigitTextFormInput(
                          initialValue: form.control(_mobile).value,
                          errorMessage: field.errorText,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChange: (value) {
                            form.control(_mobile).value = _digitsOnly(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
