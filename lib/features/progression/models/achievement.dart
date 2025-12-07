class Achievement {
  final String id;
  final String name;
  final String description;
  final bool unlocked;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.xpReward,
  });

  Achievement copyWith({bool? unlocked}) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      xpReward: xpReward,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}
