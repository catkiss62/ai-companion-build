/// A rejected/failed observation never means that a scan position was consumed.
enum MoeObservationStatus { accepted, alreadyApplied, excluded, rejected, failed }

class MoeObservationResult {
  const MoeObservationResult(this.status);
  final MoeObservationStatus status;
  bool get consumed => status == MoeObservationStatus.accepted ||
      status == MoeObservationStatus.alreadyApplied ||
      status == MoeObservationStatus.excluded;
}
