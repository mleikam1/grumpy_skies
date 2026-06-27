import '../models/weather_models.dart';

class ChaosScore {
  const ChaosScore({
    required this.value,
    required this.label,
    required this.explanation,
  });

  final int value;
  final String label;
  final String explanation;
}

class ChaosScoreService {
  const ChaosScoreService._();

  static ChaosScore evaluate(WeatherBundle weather) {
    final current = weather.current;
    final hourly = _nextHourly(weather.hourly, current.lastUpdated);
    final maxPop = hourly
        .map((hour) => hour.precipitationChance)
        .fold<int>(current.precipitationChance, (max, value) {
      return value > max ? value : max;
    });
    final maxWeatherId = [
      current.weatherId,
      ...hourly.map((hour) => hour.weatherId),
    ].whereType<int>();
    final hasThunderstorm = maxWeatherId.any(_isThunderstorm);
    final hasSnowOrIce = maxWeatherId.any(_isSnowOrIce) ||
        _mentionsAny(
          current.condition,
          const ['snow', 'sleet', 'ice', 'freezing'],
        );
    final hasRain = maxWeatherId.any(_isRain) ||
        _mentionsAny(current.condition, const ['rain', 'drizzle', 'shower']);
    final currentPrecip =
        (current.rainLastHour ?? 0) + (current.snowLastHour ?? 0);
    final wetMinutes =
        weather.minutePrecipitation.take(60).where((minute) => minute.isWet);
    final wetMinuteCount = wetMinutes.length;
    final minuteTotal = wetMinutes.fold<double>(
      0,
      (total, minute) => total + minute.precipitation,
    );
    final gustMph = current.windGustMph ?? 0;
    final windMph = current.windMph > gustMph ? current.windMph : gustMph;

    var score = 12;
    if (maxPop >= 20) score = _atLeast(score, 22);
    if (maxPop >= 40) score = _atLeast(score, 36);
    if (maxPop >= 70) score = _atLeast(score, 54);
    if (hasRain || hasSnowOrIce || currentPrecip > 0 || wetMinuteCount > 0) {
      score = _atLeast(score, 38);
    }
    if (wetMinuteCount >= 20 || minuteTotal >= 0.05 || hasSnowOrIce) {
      score = _atLeast(score, 52);
    }
    if (windMph >= 18) score = _atLeast(score, 44);
    if (windMph >= 30) score = _atLeast(score, 66);
    if (weather.alerts.isNotEmpty) score = _atLeast(score, 72);
    if (hasThunderstorm) score = _atLeast(score, 78);
    if (minuteTotal >= 0.2 || currentPrecip >= 0.2) {
      score = _atLeast(score, 82);
    }
    if (hasThunderstorm && weather.alerts.isNotEmpty) {
      score = _atLeast(score, 90);
    }

    final value = score.clamp(0, 100).toInt();
    return ChaosScore(
      value: value,
      label: _labelFor(value),
      explanation: _explanationFor(
        hasThunderstorm: hasThunderstorm,
        hasAlerts: weather.alerts.isNotEmpty,
        windMph: windMph,
        maxPop: maxPop,
        hasPrecip:
            hasRain || hasSnowOrIce || currentPrecip > 0 || wetMinuteCount > 0,
      ),
    );
  }

  static List<HourlyForecast> _nextHourly(
    List<HourlyForecast> hourly,
    DateTime reference,
  ) {
    final sorted = hourly.toList()
      ..sort((left, right) => left.time.compareTo(right.time));
    return sorted
        .where((hour) => !hour.time.isBefore(reference))
        .take(12)
        .toList();
  }

  static int _atLeast(int value, int minimum) {
    return value < minimum ? minimum : value;
  }

  static bool _isThunderstorm(int id) => id >= 200 && id < 300;

  static bool _isRain(int id) => (id >= 300 && id < 600);

  static bool _isSnowOrIce(int id) => id >= 600 && id < 700;

  static bool _mentionsAny(String value, List<String> needles) {
    final normalized = value.toLowerCase();
    return needles.any(normalized.contains);
  }

  static String _labelFor(int score) {
    if (score <= 20) return 'Calm';
    if (score <= 40) return 'Mild';
    if (score <= 65) return 'Messy';
    if (score <= 85) return 'Chaotic';
    return 'Certified chaos';
  }

  static String _explanationFor({
    required bool hasThunderstorm,
    required bool hasAlerts,
    required double windMph,
    required int maxPop,
    required bool hasPrecip,
  }) {
    if (hasThunderstorm) return 'Thunderstorm signals nearby';
    if (hasAlerts) return 'Weather alerts are active';
    if (windMph >= 30) return 'Strong gusts in the mix';
    if (maxPop >= 70) return 'High rain odds ahead';
    if (hasPrecip) return 'Precipitation is nearby';
    if (maxPop >= 35) return 'Some weather noise ahead';
    return 'Quiet signals nearby';
  }
}
