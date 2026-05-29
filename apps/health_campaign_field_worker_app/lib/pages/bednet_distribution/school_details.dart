import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/bednet_distribution/bednet_distribution.dart';
import '../../blocs/registration_deliver/household_overview/household_overview.dart';
import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../router/app_router.dart';
import '../../utils/bednet_class_selection_singleton.dart';
import '../../widgets/header/back_navigation_help_header.dart';
import 'widgets/bednet_info_card.dart';

@RoutePage()
class SchoolDetailsPage extends StatelessWidget {
  const SchoolDetailsPage({super.key});

  /// Helper method to get value from additionalFields by key
  Object? _getAdditionalFieldValue(HouseholdModel school, String key) {
    final fields = school.additionalFields?.fields ?? const <AdditionalField>[];
    final fieldMap = <String, Object?>{
      for (final field in fields)
        field.key.toLowerCase(): field.value as Object?,
    };
    return fieldMap[key.toLowerCase()];
  }

  /// Get the class index by searching for the className field that matches the selected class
  int? _getClassIndex(HouseholdModel school, String selectedClass) {
    final fields = school.additionalFields?.fields ?? const <AdditionalField>[];

    // Find the field where key ends with _className and value matches the selected class
    final classNameField = fields.firstWhere(
      (f) =>
          f.key.toLowerCase().endsWith('_classname') &&
          f.value?.toString().toLowerCase() == selectedClass.toLowerCase(),
      orElse: () => const AdditionalField('', null),
    );

    if (classNameField.key.isEmpty) {
      return null;
    }

    // Extract index from the key (e.g., class1_className -> 1)
    final keyParts = classNameField.key.toLowerCase().split('_');
    if (keyParts.isEmpty || !keyParts[0].startsWith('class')) {
      return null;
    }

    final classIndexStr = keyParts[0].replaceFirst('class', '');
    return int.tryParse(classIndexStr);
  }

  @override
  Widget build(BuildContext context) {
    final selectedClass = BednetClassSelectionSingleton().selectedClass;

    return BlocBuilder<BednetDistributionBloc, BednetDistributionState>(
      builder: (context, distributionState) {
        final school = distributionState.selectedSchool;
        if (school == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        return BlocBuilder<HouseholdOverviewBloc, HouseholdOverviewState>(
          builder: (context, overviewState) {
            final head = overviewState.householdMemberWrapper.headOfHousehold;
            final headName = [
              head?.name?.givenName,
              head?.name?.familyName,
            ].whereType<String>().join(' ').trim();

            return Scaffold(
              body: ScrollableContent(
                enableFixedDigitButton: true,
                header: const BackNavigationHelpHeaderWidget(showHelp: false),
                footer: DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    DigitButton(
                      label: 'Next',
                      type: DigitButtonType.primary,
                      size: DigitButtonSize.large,
                      mainAxisSize: MainAxisSize.max,
                      onPressed: () {
                        context.router.push(HouseholdOverviewRoute(
                          selectedClass: selectedClass,
                        ));
                      },
                    )
                  ],
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: BednetInfoCard(
                      title: 'Class Details',
                      items: [
                        MapEntry('School Name', school.bednetDisplayName),
                        if (selectedClass != null) ...[
                          MapEntry('Class Name', selectedClass),
                          // Get class index by searching for className field
                          ...(() {
                            final classIndex =
                                _getClassIndex(school, selectedClass);
                            if (classIndex == null) {
                              return <MapEntry<String, String>>[];
                            }

                            final classTeacherName = _getAdditionalFieldValue(
                                school, 'class${classIndex}_classTeacherName');
                            final totalStudents = _getAdditionalFieldValue(
                                school, 'class${classIndex}_totalStudents');

                            return [
                              if (classTeacherName != null)
                                MapEntry(
                                  'Class Teacher Name',
                                  classTeacherName.toString(),
                                ),
                              if (totalStudents != null)
                                MapEntry(
                                  'Class Total Count',
                                  totalStudents.toString(),
                                ),
                            ];
                          })(),
                        ],
                        MapEntry(
                          'School Head',
                          headName.isNotEmpty
                              ? headName
                              : school.bednetSchoolHead,
                        ),
                        MapEntry(
                          'Student Total Count',
                          school.memberCount.toString(),
                        ),
                        // MapEntry(
                        //   'Community',
                        //   school.boundaryCode ?? school.bednetCommunity,
                        // ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
