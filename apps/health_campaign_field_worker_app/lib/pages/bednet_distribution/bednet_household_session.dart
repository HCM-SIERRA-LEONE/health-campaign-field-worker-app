/// In-memory flags for the active bednet household registration session.
///
/// Persists across the Navigator stack (ITN inform success, TB flows) so the
/// [BednetHouseholdReviewPage] can reflect completion without relying on
/// ambiguous [Navigator] result values from multi-step routes.
class BednetHouseholdSession {
  BednetHouseholdSession._();

  /// Set when ITN delivery is committed in [BednetInformHouseholdPage].
  static bool itnDeliveryCompleted = false;

  /// TB screening completed for a child [individualClientReferenceId], or
  /// synthetic keys `child_0`, `child_1`, … when members are not persisted yet.
  static final Map<String, bool> tbScreeningCompletedByIndividual = {};

  static void resetForNewHousehold() {
    itnDeliveryCompleted = false;
    tbScreeningCompletedByIndividual.clear();
  }

  static void markItnDelivered() {
    itnDeliveryCompleted = true;
  }

  static void markTbScreened(String key) {
    tbScreeningCompletedByIndividual[key] = true;
  }

  static bool tbScreened(String key) =>
      tbScreeningCompletedByIndividual[key] ?? false;
}
