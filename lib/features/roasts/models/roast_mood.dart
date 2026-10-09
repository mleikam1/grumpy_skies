/// Stable content metadata. Adding an expression never changes persona IDs.
enum RoastMood {
  happy,
  excited,
  hyped,
  cozy,
  complaining,
  annoyed,
  sad,
  worried,
  confident,
  neutral;

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  /// Older packs omit mood; unfamiliar future values use the same inference.
  static RoastMood? tryParse(Object? value) {
    final token = value?.toString().trim().toLowerCase();
    for (final mood in values) {
      if (mood.name == token) return mood;
    }
    return switch (token) {
      'pleased' || 'delighted' || 'celebratory' => happy,
      'surprised' || 'shocked' => excited,
      'calm' || 'sleepy' || 'chill' => cozy,
      'smug' || 'wise' || 'reassuring' => confident,
      'concerned' => worried,
      'disappointed' || 'pouty' => sad,
      'diplomatic' => neutral,
      _ => null,
    };
  }
}

/// Content-first inference for legacy lines. Explicit editorial metadata wins.
/// No randomness, clock, theme, network request, or widget state is involved.
abstract final class RoastMoodResolver {
  static RoastMood resolve({
    required String personaId,
    required String text,
    RoastMood? explicitMood,
  }) {
    if (explicitMood != null) return explicitMood;
    final quote = text.toLowerCase().replaceAll(RegExp('[’‘]'), "'");
    bool says(String pattern) => RegExp(pattern).hasMatch(quote);
    if (says(
        r'\b(manager|complaint|refund|unacceptable|demand|customer service)\b')) {
      return RoastMood.complaining;
    }
    if (says(
        r'\b(worried|worry|concerned|careful|take shelter|stay safe|watch your step)\b')) {
      return RoastMood.worried;
    }
    if (says(
        r'\b(sad|disappointed|cry|crying|tears|pout|miss you|ruined my)\b')) {
      return RoastMood.sad;
    }
    if (says(
        r'\b(annoying|annoyed|ugh|seriously|rude|ridiculous|over it|not amused)\b')) {
      return RoastMood.annoyed;
    }
    if (says(
        r'\b(elite|hyped|hype|send it|lets go|let.s go|legendary|absolute banger)\b')) {
      return RoastMood.hyped;
    }
    if (says(r'\b(yay|woohoo|excited|splashy|hooray|wheee|can.t wait)\b')) {
      return RoastMood.excited;
    }
    if (says(
        r'\b(cozy|cosy|porch|blanket|nap|cocoa|cuddle|sweater|rocking chair)\b')) {
      return RoastMood.cozy;
    }
    if (says(
        r'\b(happy|lovely|delight|delightful|beautiful|glorious|perfect|good vibes|love this)\b')) {
      return RoastMood.happy;
    }
    if (says(
        r'\b(confident|guarantee|promise|assure|trust me|nailed it|victory|winning)\b')) {
      return RoastMood.confident;
    }
    final id =
        personaId.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    return switch (id) {
      'karen' => RoastMood.complaining,
      'frat_bro' || 'fratbro' || 'politician' => RoastMood.confident,
      'grandpa' || 'old_grandpa' => RoastMood.cozy,
      _ => RoastMood.neutral,
    };
  }
}
