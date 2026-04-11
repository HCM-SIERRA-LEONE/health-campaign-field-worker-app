import 'dart:math';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import 'package:health_campaign_field_worker_app/blocs/registration_deliver/search_households/search_households.dart';
import 'package:health_campaign_field_worker_app/models/entities/additional_fields_type.dart';
import 'package:health_campaign_field_worker_app/models/registration_deliver_model/entities/status.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/constants.dart';
import 'package:health_campaign_field_worker_app/utils/registration_deliver_utils/extensions/extensions.dart';
import 'package:intl/intl.dart';

import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';
import 'bednet_beneficiary_delivery.dart';
import 'bednet_household_session.dart';
import 'bednet_tb_assessment.dart';

/// Household screen after registration (MDT): head → Record ITN Delivery;
/// each U-5 child → TB Assessment.
class BednetHouseholdReviewPage extends LocalizedStatefulWidget {
  final String headName;
  final int memberCount;
  final int? childrenCount;
  final String? mobileNumber;
  final VoidCallback? onBack;
  final List<IndividualModel>? prefetchedMembers;
  final IndividualModel? prefetchedHead;
  final HouseholdMemberWrapper? householdMemberData;
  final void Function(IndividualModel member, TaskModel task)?
      onDeliveryRecorded;
  final VoidCallback? onBackToSchoolSelection;

  const BednetHouseholdReviewPage({
    super.key,
    super.appLocalizations,
    required this.headName,
    required this.memberCount,
    this.childrenCount,
    this.mobileNumber,
    this.onBack,
    this.prefetchedMembers,
    this.prefetchedHead,
    this.householdMemberData,
    this.onDeliveryRecorded,
    this.onBackToSchoolSelection,
  });

  @override
  State<BednetHouseholdReviewPage> createState() =>
      _BednetHouseholdReviewPageState();
}

class _ResolvedMember {
  const _ResolvedMember({
    required this.rowKey,
    required this.displayName,
    this.genderAge,
    required this.isHead,
    required this.isUnderFive,
    this.individualClientReferenceId,
  });

  final String rowKey;
  final String displayName;
  final String? genderAge;
  final bool isHead;
  final bool isUnderFive;
  final String? individualClientReferenceId;
}

class _BednetHouseholdReviewPageState
    extends LocalizedState<BednetHouseholdReviewPage> {
  static const _placeholderMemberTypeKey = 'bednetPlaceholderMemberType';
  static const Color _titleColor = Color(0xFF005A7A);
  static const Color _notDeliveredColor = Color(0xFFC6442D);
  static const Color _deliveredColor = Color(0xFF00703C);
  static const Color _badgeColor = Color(0xFF005A7A);
  static const Color _eTokenBoxBorder = Color(0xFF005A7A);
  static const Color _eTokenBoxFill = Color(0xFFE3F2FD);

  bool _itnDelivered = false;
  List<_ResolvedMember>? _members;
  bool _loadingMembers = true;

  int get _itnForDelivery => max(1, (widget.memberCount / 2).ceil());

  String get _adminArea =>
      RegistrationDeliverySingleton().boundary?.name ?? '--';

  String _eTokenForHousehold(HouseholdModel? h) {
    final fromFields = h?.additionalFields?.fields
        .firstWhereOrNull((f) => f.key == AdditionalFieldsType.eToken.toValue())
        ?.value
        ?.toString();
    if (fromFields != null && fromFields.isNotEmpty) return fromFields;
    final random = Random(widget.headName.hashCode + widget.memberCount);
    final part1 = (100 + random.nextInt(900)).toString();
    final part2 = (100 + random.nextInt(900)).toString();
    return 'E$part1-$part2';
  }

  @override
  void initState() {
    super.initState();
    _itnDelivered = BednetHouseholdSession.itnDeliveryCompleted;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    final bloc = context.read<BeneficiaryRegistrationBloc>();
    final state = bloc.state;
    final household = _householdFromState(state);
    final headIndividual = _headIndividualFromState(state);

    final householdId = household?.clientReferenceId;
    final childrenCount = widget.childrenCount ?? 0;

    List<_ResolvedMember> resolved = [];

    if (householdId != null) {
      try {
        final householdMemberRepo = context.repository<HouseholdMemberModel,
            HouseholdMemberSearchModel>(context);
        final individualRepo =
            context.repository<IndividualModel, IndividualSearchModel>(context);

        final links = await householdMemberRepo.search(
          HouseholdMemberSearchModel(
            householdClientReferenceId: [householdId],
          ),
        );

        if (links.isNotEmpty) {
          final indIds = links
              .map((e) => e.individualClientReferenceId)
              .whereNotNull()
              .toList();
          final individuals = indIds.isEmpty
              ? <IndividualModel>[]
              : await individualRepo.search(
                  IndividualSearchModel(clientReferenceId: indIds),
                );
          final byId = {
            for (final i in individuals) i.clientReferenceId: i,
          };

          final sortedLinks = [...links]..sort((a, b) {
              if (a.isHeadOfHousehold != b.isHeadOfHousehold) {
                return a.isHeadOfHousehold ? -1 : 1;
              }
              final na =
                  byId[a.individualClientReferenceId]?.name?.givenName ?? '';
              final nb =
                  byId[b.individualClientReferenceId]?.name?.givenName ?? '';
              return na.compareTo(nb);
            });

          for (final link in sortedLinks) {
            final ind = byId[link.individualClientReferenceId];
            if (ind == null) continue;
            final dob = _parseDob(ind.dateOfBirth);
            final placeholderType = _placeholderMemberType(ind, link);
            resolved.add(
              _ResolvedMember(
                rowKey: ind.clientReferenceId,
                displayName: _displayName(ind) ?? widget.headName,
                genderAge: _genderAgeLine(
                  ind,
                  dob,
                  placeholderType: placeholderType,
                ),
                isHead: link.isHeadOfHousehold,
                isUnderFive: !link.isHeadOfHousehold &&
                    (placeholderType == 'child' || _isUnderFiveYears(dob)),
                individualClientReferenceId: ind.clientReferenceId,
              ),
            );
          }
        }
      } catch (_) {
        resolved = [];
      }
    }

    final prefetchedMembers = widget.prefetchedMembers ?? const [];
    final shouldUsePrefetchedMembers = prefetchedMembers.isNotEmpty &&
        (resolved.isEmpty || prefetchedMembers.length > resolved.length);

    if (shouldUsePrefetchedMembers) {
      final headId = widget.prefetchedHead?.clientReferenceId;
      resolved = prefetchedMembers.map((member) {
        final dob = _parseDob(member.dateOfBirth);
        final placeholderType = _placeholderMemberType(member, null);
        return _ResolvedMember(
          rowKey: member.clientReferenceId,
          displayName: _displayName(member) ?? widget.headName,
          genderAge: _genderAgeLine(
            member,
            dob,
            placeholderType: placeholderType,
          ),
          isHead: member.clientReferenceId == headId,
          isUnderFive: member.clientReferenceId != headId &&
              (placeholderType == 'child' || _isUnderFiveYears(dob)),
          individualClientReferenceId: member.clientReferenceId,
        );
      }).toList()
        ..sort((a, b) {
          if (a.isHead != b.isHead) {
            return a.isHead ? -1 : 1;
          }
          return a.displayName.compareTo(b.displayName);
        });
    }

    if (resolved.isEmpty) {
      resolved = [
        _ResolvedMember(
          rowKey: headIndividual?.clientReferenceId ?? 'head',
          displayName: _displayName(headIndividual) ?? widget.headName.trim(),
          genderAge: _genderAgeLine(
            headIndividual,
            _parseDob(headIndividual?.dateOfBirth),
          ),
          isHead: true,
          isUnderFive: false,
          individualClientReferenceId: headIndividual?.clientReferenceId,
        ),
      ];
      for (var i = 0; i < childrenCount; i++) {
        resolved.add(
          _ResolvedMember(
            rowKey: 'child_$i',
            displayName: childrenCount == 1
                ? localizations.translate(i18.householdDetails.childLabel)
                : '${localizations.translate(i18.householdDetails.childLabel)} ${i + 1}',
            genderAge: _genderAgeLine(
              null,
              null,
              placeholderType: 'child',
            ),
            isHead: false,
            isUnderFive: true,
            individualClientReferenceId: null,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _members = resolved;
        _loadingMembers = false;
        _itnDelivered = BednetHouseholdSession.itnDeliveryCompleted;
      });
    }
  }

  HouseholdModel? _householdFromState(BeneficiaryRegistrationState s) {
    return s.mapOrNull(
      create: (v) => v.householdModel,
      summary: (v) => v.householdModel,
      persisted: (v) => v.householdModel,
      editHousehold: (v) => v.householdModel,
      editIndividual: (v) => v.householdModel,
      addMember: (v) => v.householdModel,
    );
  }

  IndividualModel? _headIndividualFromState(BeneficiaryRegistrationState s) {
    return s.mapOrNull(
      create: (v) => v.individualModel,
      summary: (v) => v.individualModel,
      persisted: (v) => v.individualModel,
      editHousehold: (v) => v.headOfHousehold,
      editIndividual: (v) => v.individualModel,
      addMember: (_) => null,
    );
  }

  DateTime? _parseDob(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateFormat(Constants().dateFormat).parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  bool _isUnderFiveYears(DateTime? dob) {
    if (dob == null) return false;
    return dob.age < 5;
  }

  String? _placeholderMemberType(
    IndividualModel? individual,
    HouseholdMemberModel? link,
  ) {
    final individualType = individual?.additionalFields?.fields
        .firstWhereOrNull((field) => field.key == _placeholderMemberTypeKey)
        ?.value
        ?.toString();
    if (individualType != null && individualType.isNotEmpty) {
      return individualType;
    }

    final linkType = link?.additionalFields?.fields
        .firstWhereOrNull((field) => field.key == _placeholderMemberTypeKey)
        ?.value
        ?.toString();
    if (linkType != null && linkType.isNotEmpty) {
      return linkType;
    }

    return null;
  }

  String _genderAgeLine(
    IndividualModel? ind,
    DateTime? dob, {
    String? placeholderType,
  }) {
    final genderCode = ind?.gender?.name;
    final genderLabel = (genderCode == null || genderCode.isEmpty)
        ? '--'
        : localizations.translate('CORE_COMMON_${genderCode.toUpperCase()}');
    final ys = localizations.translate(i18.searchBeneficiary.yearsAbbr);
    final ms = localizations.translate(i18.searchBeneficiary.monthsAbbr);

    if (dob == null) {
      if (placeholderType == 'child') {
        return '$genderLabel | 0 $ys 0 $ms';
      }
      return '$genderLabel | --';
    }
    final y = dob.age;
    final m = _monthComponent(dob);
    final agePart = '$y $ys | $m $ms';
    return '$genderLabel | $agePart';
  }

  String? _displayName(IndividualModel? ind) {
    if (ind == null) return null;
    final parts = [
      ind.name?.givenName,
      ind.name?.familyName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  int _monthComponent(DateTime dob) {
    final now = DateTime.now();
    var months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months--;
    final y = dob.age;
    return months - y * 12;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      backgroundColor: theme.colorTheme.paper.secondary,
      body: ScrollableContent(
        enableFixedDigitButton: false,
        header: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: spacer2),
              child: widget.onBack != null
                  ? _InlineBackHeader(
                      label: localizations.translate(i18.common.coreCommonBack),
                      onBack: widget.onBack!,
                    )
                  : const BackNavigationHelpHeaderWidget(showHelp: false),
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: spacer2,
                vertical: spacer2,
              ),
              child: _loadingMembers
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(spacer4),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate(
                              i18.householdDetails.householdScreenTitle),
                          style: textTheme.headingXl.copyWith(
                            color: _titleColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: spacer2),
                        DigitCard(
                          children: [
                            _infoRow(
                              textTheme,
                              localizations.translate(
                                  i18.householdDetails.householdHeadLabel),
                              widget.headName,
                            ),
                            _infoRow(
                              textTheme,
                              localizations.translate(
                                  i18.householdDetails.memberCountLabel),
                              widget.memberCount.toString().padLeft(2, '0'),
                            ),
                            _infoRow(
                              textTheme,
                              localizations.translate(
                                  i18.householdDetails.administrativeAreaLabel),
                              _adminArea,
                            ),
                          ],
                        ),
                        const SizedBox(height: spacer2),
                        ..._buildMemberCards(theme, textTheme),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMemberCards(ThemeData theme, dynamic textTheme) {
    final members = _members ?? [];
    final household =
        _householdFromState(context.read<BeneficiaryRegistrationBloc>().state);
    final eToken = _eTokenForHousehold(household);

    final out = <Widget>[];
    for (final m in members) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: spacer2),
          child: _buildOneMemberCard(
            theme: theme,
            textTheme: textTheme,
            member: m,
            eToken: eToken,
          ),
        ),
      );
    }
    return out;
  }

  Widget _buildOneMemberCard({
    required ThemeData theme,
    required dynamic textTheme,
    required _ResolvedMember member,
    required String eToken,
  }) {
    if (member.isHead) {
      return _buildHouseholdHeadCard(theme, textTheme, member, eToken);
    }
    if (member.isUnderFive) {
      return _buildU5ChildCard(theme, textTheme, member);
    }
    return _buildOtherMemberCard(theme, textTheme, member);
  }

  Widget _buildHouseholdHeadCard(
    ThemeData theme,
    dynamic textTheme,
    _ResolvedMember member,
    String eToken,
  ) {
    final delivered = _itnDelivered || _hasDeliveredCurrentRound(member);

    return _MemberCard(
      theme: theme,
      textTheme: textTheme,
      name: member.displayName,
      genderAge: member.genderAge,
      leading: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: spacer1, horizontal: spacer2),
        decoration: BoxDecoration(
          color: _eTokenBoxFill,
          border: Border.all(color: _eTokenBoxBorder),
        ),
        child: Text(
          eToken,
          textAlign: TextAlign.center,
          style: textTheme.headingM.copyWith(
            color: _eTokenBoxBorder,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      statusWidget: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: _badgeColor),
          const SizedBox(width: 4),
          Text(
            localizations.translate(i18.householdDetails.householdHeadLabel),
            style: textTheme.bodyS.copyWith(color: _badgeColor),
          ),
        ],
      ),
      deliveryStatusWidget: delivered
          ? _statusChip(
              label:
                  localizations.translate(i18.householdDetails.deliveredLabel),
              color: _deliveredColor,
              icon: Icons.check_circle_outline,
            )
          : _statusChip(
              label: localizations
                  .translate(i18.householdDetails.notDeliveredLabel),
              color: _notDeliveredColor,
              icon: Icons.cancel_outlined,
            ),
      actionLabel:
          localizations.translate(i18.householdDetails.recordItnDelivery),
      onAction: () => _onRecordItnDelivery(member),
    );
  }

  Widget _buildU5ChildCard(
    ThemeData theme,
    dynamic textTheme,
    _ResolvedMember member,
  ) {
    final screened = BednetHouseholdSession.tbScreened(member.rowKey);

    return _MemberCard(
      theme: theme,
      textTheme: textTheme,
      name: member.displayName,
      genderAge: member.genderAge,
      leading: null,
      statusWidget: null,
      deliveryStatusWidget: screened
          ? _statusChip(
              label: localizations
                  .translate(i18.householdDetails.tbScreenedStatus),
              color: _deliveredColor,
              icon: Icons.check_circle_outline,
            )
          : _statusChip(
              label: localizations
                  .translate(i18.householdDetails.tbPendingScreening),
              color: _notDeliveredColor,
              icon: Icons.cancel_outlined,
            ),
      actionLabel:
          localizations.translate(i18.householdDetails.tbAssessmentLabel),
      onAction: () => _onTbAssessment(member),
    );
  }

  Widget _buildOtherMemberCard(
    ThemeData theme,
    dynamic textTheme,
    _ResolvedMember member,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(spacer2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.displayName,
              style: textTheme.headingM.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (member.genderAge != null) ...[
              const SizedBox(height: 2),
              Text(member.genderAge!, style: textTheme.bodyS),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasDeliveredCurrentRound(_ResolvedMember member) {
    final wrapper = widget.householdMemberData;
    if (wrapper == null) return false;

    final projectBeneficiary = wrapper.projectBeneficiaries?.firstWhereOrNull(
      (element) => element.beneficiaryClientReferenceId == member.rowKey,
    );

    if (projectBeneficiary == null) return false;

    final currentCycleId = RegistrationDeliverySingleton()
            .projectType
            ?.cycles
            ?.firstWhereOrNull(
              (cycle) =>
                  cycle.startDate < DateTime.now().millisecondsSinceEpoch &&
                  cycle.endDate > DateTime.now().millisecondsSinceEpoch,
            )
            ?.id ??
        1;

    final cycleToken = '0$currentCycleId';

    return (wrapper.tasks ?? []).any((task) {
      if (task.projectBeneficiaryClientReferenceId !=
          projectBeneficiary.clientReferenceId) {
        return false;
      }
      final cycleIndex = task.additionalFields?.fields
          .firstWhereOrNull(
            (field) => field.key == AdditionalFieldsType.cycleIndex.toValue(),
          )
          ?.value
          ?.toString();
      return cycleIndex == cycleToken &&
          (task.status == Status.administeredSuccess.toValue() ||
              task.status == Status.delivered.toValue());
    });
  }

  void _onRecordItnDelivery(_ResolvedMember member) {
    final beneficiary =
        (widget.householdMemberData?.members ?? const <IndividualModel>[])
            .firstWhereOrNull(
                (element) => element.clientReferenceId == member.rowKey);
    if (beneficiary == null || widget.householdMemberData == null) return;

    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BednetBeneficiaryDeliveryPage(
          householdMember: widget.householdMemberData!,
          beneficiary: beneficiary,
          onBackToSchoolSelection: widget.onBackToSchoolSelection ??
              () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
          onDeliveryRecorded: (task) {
            widget.onDeliveryRecorded?.call(beneficiary, task);
          },
        ),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _itnDelivered = BednetHouseholdSession.itnDeliveryCompleted;
        });
      }
    });
  }

  void _onTbAssessment(_ResolvedMember member) {
    final label = member.displayName;
    final projectBeneficiary =
        widget.householdMemberData?.projectBeneficiaries?.firstWhereOrNull(
      (element) => element.beneficiaryClientReferenceId == member.rowKey,
    );
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BednetTbAssessmentPage(
          childLabel: label,
          householdClientReferenceId: _householdFromState(
                  context.read<BeneficiaryRegistrationBloc>().state)
              ?.clientReferenceId,
          childIndividualClientReferenceId: member.individualClientReferenceId,
          projectBeneficiaryClientReferenceId:
              projectBeneficiary?.clientReferenceId,
          sessionRowKey: member.rowKey,
          onBackToSearch: widget.onBack,
        ),
      ),
    )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _infoRow(dynamic textTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: textTheme.bodyL.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: spacer2),
          Expanded(
            flex: 3,
            child: Text(value, style: textTheme.bodyL),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _InlineBackHeader extends StatelessWidget {
  const _InlineBackHeader({
    required this.label,
    required this.onBack,
  });

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: spacer2, top: spacer4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onBack,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: Theme.of(context).colorTheme.primary.primary2,
          ),
          icon: const Icon(Icons.arrow_left),
          label: Text(label),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.theme,
    required this.textTheme,
    required this.name,
    required this.genderAge,
    this.leading,
    required this.statusWidget,
    required this.deliveryStatusWidget,
    required this.actionLabel,
    required this.onAction,
  });

  final ThemeData theme;
  final dynamic textTheme;
  final String name;
  final String? genderAge;
  final Widget? leading;
  final Widget? statusWidget;
  final Widget deliveryStatusWidget;
  final String actionLabel;
  final VoidCallback onAction;

  static const Color _orange = Color(0xFFCC4C02);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(spacer2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(height: spacer2),
            ],
            Text(
              name,
              style: textTheme.headingM.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (genderAge != null) ...[
              const SizedBox(height: 2),
              Text(genderAge!, style: textTheme.bodyS),
            ],
            if (statusWidget != null) ...[
              const SizedBox(height: spacer1),
              statusWidget!,
            ],
            const SizedBox(height: spacer1),
            deliveryStatusWidget,
            const SizedBox(height: spacer2),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: spacer2),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: textTheme.headingM.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
