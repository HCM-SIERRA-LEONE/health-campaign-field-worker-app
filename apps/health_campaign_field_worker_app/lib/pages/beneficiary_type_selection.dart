import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../widgets/header/back_navigation_help_header.dart';
import '../widgets/localized.dart';

@RoutePage()
class BeneficiaryTypeSelectionPage extends LocalizedStatefulWidget {
  const BeneficiaryTypeSelectionPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<BeneficiaryTypeSelectionPage> createState() =>
      _BeneficiaryTypeSelectionPageState();
}

class _BeneficiaryTypeSelectionPageState
    extends LocalizedState<BeneficiaryTypeSelectionPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      body: ScrollableContent(
        header: const BackNavigationHelpHeaderWidget(
          showHelp: false,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(spacer2),
            child: Container(
              padding: const EdgeInsets.fromLTRB(spacer2, spacer4, spacer2, spacer3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(spacer1),
                border: Border.all(color: const Color(0xFFE3E3E3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your beneficiary\ntype',
                    style: textTheme.headingXl.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: spacer3),
                  Row(
                    children: [
                      Expanded(
                        child: _BeneficiaryTypeCard(
                          icon: Icons.store,
                          label: 'School',
                          onPressed: () {
                            context.router.push(
                              const BednetDistributionWrapperRoute(),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _BeneficiaryTypeCard(
                          icon: Icons.home,
                          label: 'Household',
                          onPressed: () {},
                        ),
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
}

class _BeneficiaryTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _BeneficiaryTypeCard({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacer1),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(spacer1),
        child: Container(
          height: 136,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(spacer1),
            border: Border.all(color: const Color(0xFFDCDCDC)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: theme.colorTheme.primary.primary1,
                size: 42,
              ),
              const SizedBox(height: spacer3),
              Text(
                label,
                style: textTheme.headingM.copyWith(
                  color: const Color(0xFF0C5B74),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
