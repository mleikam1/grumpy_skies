/// Explicit local opinions only. They never infer weather, activities or identity.
enum RoastFeedback { liked, disliked }

class RoastLocalPreferences {
  static const limit = 200;
  final _favorites = <String>{};
  final _feedback = <String, RoastFeedback>{};

  Set<String> get favorites => Set.unmodifiable(_favorites);
  Map<String, RoastFeedback> get feedback => Map.unmodifiable(_feedback);

  static bool _validId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(id);

  bool setFavorite(String id, bool favorite) {
    if (!_validId(id) || _favorites.contains(id) == favorite) return false;
    if (favorite) {
      _favorites.add(id);
      while (_favorites.length > limit) {
        _favorites.remove(_favorites.first);
      }
    } else {
      _favorites.remove(id);
    }
    return true;
  }

  bool setFeedback(String id, RoastFeedback? value) {
    if (!_validId(id) || _feedback[id] == value) return false;
    _feedback.remove(id);
    if (value != null) _feedback[id] = value;
    while (_feedback.length > limit) {
      _feedback.remove(_feedback.keys.first);
    }
    return true;
  }

  /// Used only after hard eligibility, relevance and repetition filtering.
  /// Dislikes reduce chance but cannot remove the last truthful option.
  Map<String, double> get weights => {
        for (final id in {..._favorites, ..._feedback.keys})
          id: (_favorites.contains(id) ? 1.5 : 1.0) *
              switch (_feedback[id]) {
                RoastFeedback.liked => 2.0,
                RoastFeedback.disliked => 0.5,
                null => 1.0,
              }
      };

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'favorites': _favorites.toList(),
        'feedback': {
          for (final entry in _feedback.entries) entry.key: entry.value.name
        }
      };

  void restore(Map<String, dynamic> json) {
    if (json['schema'] != 1) return;
    _favorites.clear();
    _feedback.clear();
    final favorites = json['favorites'];
    if (favorites is List) {
      for (final value in favorites.whereType<String>()) {
        setFavorite(value, true);
      }
    }
    final feedback = json['feedback'];
    if (feedback is Map) {
      for (final entry in feedback.entries) {
        if (entry.key is! String) continue;
        final value = RoastFeedback.values
            .where((v) => v.name == entry.value)
            .firstOrNull;
        if (value != null) setFeedback(entry.key as String, value);
      }
    }
  }
}
