/// Application-owned vocabulary. Rules contain data, never executable code.
enum RoastScope { current, hourly, today, commute, weekend }

enum RoastActivity { walking, commuting, grilling, outdoorExercise, stayingIn }

extension RoastActivityFact on RoastActivity {
  String get fact => switch (this) {
        RoastActivity.outdoorExercise => 'activity_outdoor_exercise',
        RoastActivity.stayingIn => 'activity_staying_in',
        _ => 'activity_$name',
      };
}

class RoastNumericConstraint {
  const RoastNumericConstraint({
    required this.fact,
    required this.unit,
    this.min,
    this.max,
  });
  final String fact;
  final String unit;
  final double? min;
  final double? max;
  factory RoastNumericConstraint.fromJson(Map<String, dynamic> json) =>
      RoastNumericConstraint(
        fact: json['fact'] as String,
        unit: json['unit'] as String,
        min: (json['min'] as num?)?.toDouble(),
        max: (json['max'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {
        'fact': fact,
        'unit': unit,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };
}

class RoastRule {
  const RoastRule({
    required this.id,
    this.requiredAll = const [],
    this.anyOf = const [],
    this.forbidden = const [],
    this.scopes = const [],
    this.maxAgeMinutes,
    this.placeholders = const [],
    this.numeric = const [],
  });
  final String id;
  final List<String> requiredAll;

  /// Every group must have at least one proven fact.
  final List<List<String>> anyOf;
  final List<String> forbidden;
  final List<RoastScope> scopes;
  final int? maxAgeMinutes;
  final List<String> placeholders;
  final List<RoastNumericConstraint> numeric;
  factory RoastRule.fromJson(Map<String, dynamic> json) => RoastRule(
        id: json['id'] as String,
        requiredAll:
            List<String>.unmodifiable(json['required_all'] ?? const []),
        anyOf: List<List<String>>.unmodifiable([
          for (final group in json['any_of'] ?? const [])
            List<String>.unmodifiable(group as List),
        ]),
        forbidden: List<String>.unmodifiable(json['forbidden'] ?? const []),
        scopes: List<RoastScope>.unmodifiable([
          for (final scope in json['scopes'] ?? const [])
            RoastScope.values.byName(scope as String),
        ]),
        maxAgeMinutes: (json['max_age_minutes'] as num?)?.toInt(),
        placeholders:
            List<String>.unmodifiable(json['placeholders'] ?? const []),
        numeric: List<RoastNumericConstraint>.unmodifiable([
          for (final item in json['numeric'] ?? const [])
            RoastNumericConstraint.fromJson(
                (item as Map).cast<String, dynamic>()),
        ]),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'required_all': requiredAll,
        if (anyOf.isNotEmpty) 'any_of': anyOf,
        if (forbidden.isNotEmpty) 'forbidden': forbidden,
        if (scopes.isNotEmpty) 'scopes': scopes.map((e) => e.name).toList(),
        if (maxAgeMinutes != null) 'max_age_minutes': maxAgeMinutes,
        if (placeholders.isNotEmpty) 'placeholders': placeholders,
        if (numeric.isNotEmpty)
          'numeric': numeric.map((e) => e.toJson()).toList(),
      };
}
