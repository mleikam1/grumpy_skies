import '../../models/weather_models.dart';
import '../../models/weather_time.dart';
import '../forecast/models/hourly_timeline.dart';

/// Presentation of provider-valid instants. A successful metadata download is
/// deliberately separate from observation time and a forecast's issue time.
class RadarPresentation {
  const RadarPresentation({
    required this.mode,
    required this.frames,
    required this.frame,
    required this.now,
    this.timezone,
    this.timezoneOffset,
    this.refreshedAt,
  });

  final RadarMode mode;
  final List<RadarFrame> frames;
  final RadarFrame? frame;
  final DateTime now;
  final String? timezone;
  final int? timezoneOffset;

  /// Assigned only after a successful metadata response by the state owner.
  final DateTime? refreshedAt;

  bool get isForecast => mode.isFutureCast;

  // An observation's fixed offset cannot predict a later DST transition.
  int? get _offset => isForecast ? null : timezoneOffset;

  DateTime _instant(int timestamp) => DateTime.fromMillisecondsSinceEpoch(
        timestamp * 1000,
        isUtc: true,
      );

  DateTime _local(DateTime instant) =>
      weatherLocalTime(instant, timezone, _offset) ?? instant.toUtc();

  bool get usesUtcFallback => weatherLocalTime(now, timezone, _offset) == null;

  bool get isLatestObserved {
    final selected = frame;
    if (isForecast || selected == null || !selected.renderable) return false;
    final observed = frames.where((candidate) =>
        candidate.renderable && candidate.type != RadarFrameType.forecast);
    if (observed.isEmpty) return false;
    return selected.type != RadarFrameType.forecast &&
        !observed.any((candidate) => candidate.timestamp > selected.timestamp);
  }

  String get title {
    final selected = frame;
    if (selected == null) {
      return isForecast ? 'FutureCast unavailable' : 'Radar unavailable';
    }
    final time = _instant(selected.timestamp);
    if (isForecast) return '${_dayLabel(time)} · ${_clockLabel(time)}';
    final prefix = isLatestObserved ? 'Latest' : 'Observed';
    final day =
        _sameDay(_local(time), _local(now)) ? '' : '${_dayLabel(time)} · ';
    return '$prefix · $day${_clockLabel(time)}';
  }

  String get subtitle {
    final selected = frame;
    if (isForecast) return 'Forecast precipitation';
    if (selected == null) return 'No observed frames available';
    final age = now.toUtc().difference(_instant(selected.timestamp));
    if (age < const Duration(minutes: -1)) {
      return 'Observation time is ahead of this clock';
    }
    return 'Observed ${_age(age)}';
  }

  String timeLabelFor(RadarFrame selected) =>
      _fullTimeLabel(_instant(selected.timestamp));

  String get frameTimeLabel => frame == null
      ? 'No frame selected'
      : _fullTimeLabel(_instant(frame!.timestamp));

  String? get refreshLabel => refreshedAt == null
      ? null
      : 'Metadata refreshed ${_age(now.toUtc().difference(refreshedAt!.toUtc()))}';

  String? get refreshedTimeLabel =>
      refreshedAt == null ? null : _fullTimeLabel(refreshedAt!);

  /// The existing backend does not return a model run/issue timestamp.
  String get forecastIssueTimeLabel => 'Not provided by this radar source';

  String get sourceLabel => switch (frame?.source ?? mode.sourceParam) {
        'noaa_mrms' => 'NOAA/NWS radar',
        'openweather_futurecast' => 'OpenWeather forecast precipitation',
        'openweather_global' => 'OpenWeather global precipitation radar',
        _ => 'Radar source unavailable',
      };

  String get timelineValue =>
      '${isForecast ? 'Forecast precipitation' : isLatestObserved ? 'Latest observation' : 'Historical observation'}, $frameTimeLabel';

  /// Tick positions use elapsed time, not a manufactured regular cadence.
  /// Endpoints and the real frame nearest the midpoint give at most 3 labels.
  List<RadarTimelineTick> get timelineTicks {
    final available = _availableIndices;
    if (available.isEmpty) return const [];
    if (available.length == 1) return [_tick(available.single)];
    final first = available.first;
    final last = available.last;
    final middle = nearestFrameIndex(0.5);
    final indices = <int>{first, if (middle != null) middle, last}.toList()
      ..sort((left, right) =>
          frames[left].timestamp.compareTo(frames[right].timestamp));
    return List.unmodifiable(indices.map(_tick));
  }

  List<int> get _availableIndices {
    final indices = [
      for (var index = 0; index < frames.length; index++)
        if (frames[index].renderable) index,
    ];
    return indices
      ..sort((left, right) =>
          frames[left].timestamp.compareTo(frames[right].timestamp));
  }

  /// Returns the original list index so the state owner's frame identity stays
  /// unchanged. The user can scrub across missing/irregular intervals safely.
  int? nearestFrameIndex(double fraction) {
    final available = _availableIndices;
    if (available.isEmpty) return null;
    final first = frames[available.first].timestamp;
    final last = frames[available.last].timestamp;
    final target = first + (last - first) * fraction.clamp(0.0, 1.0);
    var best = available.first;
    for (final index in available.skip(1)) {
      if ((frames[index].timestamp - target).abs() <
          (frames[best].timestamp - target).abs()) {
        best = index;
      }
    }
    return best;
  }

  double fractionForFrame(RadarFrame selected) {
    final available = _availableIndices;
    if (available.length < 2) return 0;
    final first = frames[available.first].timestamp;
    final last = frames[available.last].timestamp;
    if (first == last) return 0;
    return ((selected.timestamp - first) / (last - first)).clamp(0.0, 1.0);
  }

  RadarTimelineTick _tick(int index) {
    final item = frames[index];
    final instant = _instant(item.timestamp);
    final daysDiffer = _availableIndices.any((other) =>
        !_sameDay(_local(_instant(frames[other].timestamp)), _local(instant)));
    final label = daysDiffer
        ? '${_shortDate(instant)} · ${_clockLabel(instant)}'
        : _clockLabel(instant);
    return RadarTimelineTick(
      index: index,
      timestamp: item.timestamp,
      fraction: fractionForFrame(item),
      label: label,
    );
  }

  String _dayLabel(DateTime time) => _sameDay(_local(time), _local(now))
      ? 'Today'
      : forecastDateLabel(time, timezone, _offset);

  String _shortDate(DateTime time) {
    final local = _local(time);
    return '${local.month}/${local.day}';
  }

  String _clockLabel(DateTime time) {
    final clock = forecastHourLabel(time, timezone, _offset);
    if (usesUtcFallback) return '$clock UTC';
    if (_repeatedWallTime(time)) {
      return '$clock ${forecastUtcOffset(time, timezone, _offset)}';
    }
    return clock;
  }

  String _fullTimeLabel(DateTime time) {
    final local = _local(time);
    final date = forecastDateLabel(time, timezone, _offset);
    final seconds =
        local.second == 0 ? '' : ':${local.second.toString().padLeft(2, '0')}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$date, ${local.year} · $hour:$minute$seconds '
        '${local.hour >= 12 ? 'PM' : 'AM'} · '
        '${forecastUtcOffset(time, timezone, _offset)}';
  }

  bool _repeatedWallTime(DateTime time) {
    final local = _local(time);
    final offset = forecastUtcOffset(time, timezone, _offset);
    return frames.any((candidate) {
      final candidateTime = _instant(candidate.timestamp);
      final other = _local(candidateTime);
      return _sameDay(local, other) &&
          local.hour == other.hour &&
          offset != forecastUtcOffset(candidateTime, timezone, _offset);
    });
  }

  static bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static String _age(Duration duration) {
    if (duration.inMinutes < 1) return 'just now';
    if (duration.inHours < 1) return '${duration.inMinutes} min ago';
    if (duration.inDays < 1) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours} hr${minutes == 0 ? '' : ' $minutes min'} ago';
    }
    return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'} ago';
  }
}

class RadarTimelineTick {
  const RadarTimelineTick({
    required this.index,
    required this.timestamp,
    required this.fraction,
    required this.label,
  });

  final int index;
  final int timestamp;
  final double fraction;
  final String label;
}
