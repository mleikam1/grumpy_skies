/// Optional, device-local interests. An interest never proves an outing exists.
class GuidancePreferences {
  const GuidancePreferences({
    this.enabled = true,
    this.dogWalking = false,
    this.cycling = false,
    this.walking = false,
    this.driving = false,
    this.commuteStartMinute = 420,
    this.commuteEndMinute = 540,
    this.outingMinutes = 30,
    this.commuteDaysMask = 31,
  });

  final bool enabled, dogWalking, cycling, walking, driving;
  final int commuteStartMinute,
      commuteEndMinute,
      outingMinutes,
      commuteDaysMask;
  bool commutesOn(int weekday) => commuteDaysMask & (1 << (weekday - 1)) != 0;

  GuidancePreferences copyWith({
    bool? enabled,
    bool? dogWalking,
    bool? cycling,
    bool? walking,
    bool? driving,
    int? commuteStartMinute,
    int? commuteEndMinute,
    int? outingMinutes,
    int? commuteDaysMask,
  }) =>
      GuidancePreferences(
        commuteDaysMask:
            (commuteDaysMask ?? this.commuteDaysMask).clamp(0, 127),
        enabled: enabled ?? this.enabled,
        dogWalking: dogWalking ?? this.dogWalking,
        cycling: cycling ?? this.cycling,
        walking: walking ?? this.walking,
        driving: driving ?? this.driving,
        commuteStartMinute:
            (commuteStartMinute ?? this.commuteStartMinute).clamp(0, 1439),
        commuteEndMinute:
            (commuteEndMinute ?? this.commuteEndMinute).clamp(0, 1439),
        outingMinutes: (outingMinutes ?? this.outingMinutes).clamp(10, 180),
      );

  Map<String, Object> toJson() => {
        'commuteDaysMask': commuteDaysMask,
        'enabled': enabled,
        'dogWalking': dogWalking,
        'cycling': cycling,
        'walking': walking,
        'driving': driving,
        'commuteStartMinute': commuteStartMinute,
        'commuteEndMinute': commuteEndMinute,
        'outingMinutes': outingMinutes,
      };

  factory GuidancePreferences.fromJson(Object? value) {
    if (value is! Map) return const GuidancePreferences();
    bool flag(String key, bool fallback) =>
        value[key] is bool ? value[key] as bool : fallback;
    int integer(String key, int fallback, int low, int high) {
      final v = value[key];
      return v is int && v >= low && v <= high ? v : fallback;
    }

    return GuidancePreferences(
      commuteDaysMask: integer('commuteDaysMask', 31, 0, 127),
      enabled: flag('enabled', true),
      dogWalking: flag('dogWalking', false),
      cycling: flag('cycling', false),
      walking: flag('walking', false),
      driving: flag('driving', false),
      commuteStartMinute: integer('commuteStartMinute', 420, 0, 1439),
      commuteEndMinute: integer('commuteEndMinute', 540, 0, 1439),
      outingMinutes: integer('outingMinutes', 30, 10, 180),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GuidancePreferences &&
      commuteDaysMask == other.commuteDaysMask &&
      enabled == other.enabled &&
      dogWalking == other.dogWalking &&
      cycling == other.cycling &&
      walking == other.walking &&
      driving == other.driving &&
      commuteStartMinute == other.commuteStartMinute &&
      commuteEndMinute == other.commuteEndMinute &&
      outingMinutes == other.outingMinutes;
  @override
  int get hashCode => Object.hash(
      enabled,
      dogWalking,
      cycling,
      walking,
      driving,
      commuteStartMinute,
      commuteEndMinute,
      outingMinutes,
      commuteDaysMask);
}
