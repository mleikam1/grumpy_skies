import 'guidance_evidence.dart';

class GuidanceCandidate {
  GuidanceCandidate(
      {required this.ruleId,
      required this.familyId,
      required this.templateId,
      required this.text,
      required this.semanticDedupeKey,
      required this.situationFingerprint,
      required this.activity,
      required this.location,
      required Iterable<EvidenceField<Object>> supportedFacts,
      required this.validFrom,
      required this.validUntil,
      required this.priority,
      required this.reason,
      this.serious = false,
      this.comparisonWindow,
      this.alert,
      this.reliability = 0,
      this.specificity = 0})
      : supportedFacts = List.unmodifiable(supportedFacts);
  final String ruleId,
      familyId,
      templateId,
      text,
      semanticDedupeKey,
      situationFingerprint,
      reason;
  final GuidanceActivity activity;
  final GuidanceLocation location;
  final List<EvidenceField<Object>> supportedFacts;
  final DateTime validFrom, validUntil;
  final int priority, reliability, specificity;
  final bool serious;
  final GuidanceInterval? comparisonWindow;
  final GuidanceAlert? alert;
  bool validAt(DateTime now) =>
      !now.isBefore(validFrom) && now.isBefore(validUntil);
}
