class XpState {
  final int currentXp;
  final int level;
  final int streakCount;
  final DateTime? lastOpened;
  final bool viewedMorning;
  final bool viewedAfternoon;
  final bool viewedNight;

  const XpState({
    required this.currentXp,
    required this.level,
    required this.streakCount,
    required this.lastOpened,
    required this.viewedMorning,
    required this.viewedAfternoon,
    required this.viewedNight,
  });

  XpState copyWith({
    int? currentXp,
    int? level,
    int? streakCount,
    DateTime? lastOpened,
    bool? viewedMorning,
    bool? viewedAfternoon,
    bool? viewedNight,
  }) {
    return XpState(
      currentXp: currentXp ?? this.currentXp,
      level: level ?? this.level,
      streakCount: streakCount ?? this.streakCount,
      lastOpened: lastOpened ?? this.lastOpened,
      viewedMorning: viewedMorning ?? this.viewedMorning,
      viewedAfternoon: viewedAfternoon ?? this.viewedAfternoon,
      viewedNight: viewedNight ?? this.viewedNight,
    );
  }

  factory XpState.initial() {
    return const XpState(
      currentXp: 0,
      level: 1,
      streakCount: 0,
      lastOpened: null,
      viewedMorning: false,
      viewedAfternoon: false,
      viewedNight: false,
    );
  }

  factory XpState.fromJson(Map<String, dynamic> json) {
    return XpState(
      currentXp: json['currentXp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      streakCount: json['streakCount'] as int? ?? 0,
      lastOpened: json['lastOpened'] != null
          ? DateTime.tryParse(json['lastOpened'] as String)
          : null,
      viewedMorning: json['viewedMorning'] as bool? ?? false,
      viewedAfternoon: json['viewedAfternoon'] as bool? ?? false,
      viewedNight: json['viewedNight'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentXp': currentXp,
      'level': level,
      'streakCount': streakCount,
      'lastOpened': lastOpened?.toIso8601String(),
      'viewedMorning': viewedMorning,
      'viewedAfternoon': viewedAfternoon,
      'viewedNight': viewedNight,
    };
  }
}
