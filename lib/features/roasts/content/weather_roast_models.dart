import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import 'roast_content_models.dart';

// Preserve the existing app-facing import while keeping editor tooling pure Dart.
export 'roast_content_models.dart';

extension RoastLineWeatherConstraints on RoastLine {
  bool matchesStaticWeatherConstraints(WeatherRoastContext context) {
    if (conditionCodes.isNotEmpty &&
        context.conditionCode != null &&
        !conditionCodes.contains(context.conditionCode)) {
      return false;
    }

    final minTemp = tempMinF;
    if (minTemp != null && context.tempF < minTemp) return false;

    final maxTemp = tempMaxF;
    if (maxTemp != null && context.tempF > maxTemp) return false;

    final minHumidity = humidityMin;
    if (minHumidity != null && context.humidity < minHumidity) return false;

    final minWind = windMinMph;
    if (minWind != null && context.windMph < minWind) return false;

    final minPrecip = precipMinPercent;
    if (minPrecip != null && context.precipChance < minPrecip) return false;

    return true;
  }
}

class WeatherRoastContext {
  const WeatherRoastContext({
    required this.city,
    required this.tempF,
    required this.feelsLikeF,
    required this.condition,
    required this.humidity,
    required this.windMph,
    required this.precipChance,
    required this.daypart,
    required this.tags,
    this.conditionCode,
    this.temperatureUnit = TemperatureUnit.fahrenheit,
  });

  final TemperatureUnit temperatureUnit;
  final String city;
  final int tempF;
  final int feelsLikeF;
  final String condition;
  final int humidity;
  final double windMph;
  final int precipChance;
  final Daypart daypart;
  final Set<WeatherRoastTag> tags;
  final int? conditionCode;

  factory WeatherRoastContext.fromWeatherBundle(
    WeatherBundle weather, {
    DateTime? now,
    TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
  }) {
    final current = weather.current;
    final observedAt = now ?? current.displayUpdatedAt;
    final tempF = current.temperatureF.round();
    final feelsLikeF = current.feelsLikeF.round();
    final windMph = current.windMph;
    final precipChance = current.precipitationChance;
    final conditionCode = current.weatherId;
    final normalizedCondition = current.condition.toLowerCase();
    final weatherMain = (current.weatherMain ?? '').toLowerCase();
    final tags = <WeatherRoastTag>{};

    if (tempF >= 90) tags.add(WeatherRoastTag.hot);
    if (tempF <= 32) tags.add(WeatherRoastTag.cold);
    if (current.humidity >= 65 && tempF >= 75) {
      tags.add(WeatherRoastTag.humid);
    }
    if (current.humidity <= 30) tags.add(WeatherRoastTag.dry);
    if (windMph >= 20) tags.add(WeatherRoastTag.windy);
    if (current.uvIndex >= 7) tags.add(WeatherRoastTag.highUv);
    if (_isBadAir(current.aqi, current.aqiCategory)) {
      tags.add(WeatherRoastTag.badAir);
    }

    if (_isStorm(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.storm);
    }
    if (_isSnow(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.snow);
    }
    if (_isFog(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.fog);
    }
    if (_isRain(conditionCode, normalizedCondition, weatherMain) ||
        precipChance >= 50) {
      tags.add(
        _isHeavyRain(
          conditionCode,
          normalizedCondition,
          precipChance,
          current.rainLastHour,
        )
            ? WeatherRoastTag.heavyRain
            : WeatherRoastTag.lightRain,
      );
    }
    if (_isClear(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.clear);
    }
    if (_isPartlyCloudy(conditionCode, normalizedCondition)) {
      tags.add(WeatherRoastTag.partlyCloudy);
    } else if (_isCloudy(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.cloudy);
    }

    if (weather.alerts.isNotEmpty ||
        current.alertIds.isNotEmpty ||
        _mentionsSevereWeather(normalizedCondition)) {
      tags.add(WeatherRoastTag.severe);
    }

    final gross = tags.contains(WeatherRoastTag.humid) ||
        tags.contains(WeatherRoastTag.heavyRain) ||
        tags.contains(WeatherRoastTag.badAir) ||
        tags.contains(WeatherRoastTag.fog) ||
        (tags.contains(WeatherRoastTag.hot) &&
            tags.contains(WeatherRoastTag.highUv));
    if (gross) tags.add(WeatherRoastTag.gross);

    final commuteRisk = tags.contains(WeatherRoastTag.lightRain) ||
        tags.contains(WeatherRoastTag.heavyRain) ||
        tags.contains(WeatherRoastTag.storm) ||
        tags.contains(WeatherRoastTag.snow) ||
        tags.contains(WeatherRoastTag.fog) ||
        tags.contains(WeatherRoastTag.windy) ||
        tags.contains(WeatherRoastTag.severe);
    if (commuteRisk) tags.add(WeatherRoastTag.commuteRisk);

    final nice = tempF >= 60 &&
        tempF <= 82 &&
        !gross &&
        !commuteRisk &&
        !tags.contains(WeatherRoastTag.cold);
    if (nice) tags.add(WeatherRoastTag.nice);

    final weekend = observedAt.weekday == DateTime.friday ||
        observedAt.weekday == DateTime.saturday ||
        observedAt.weekday == DateTime.sunday;
    if (weekend && nice) tags.add(WeatherRoastTag.weekendGood);

    if (tags.isEmpty) tags.add(WeatherRoastTag.fallback);

    return WeatherRoastContext(
      city: _cityName(current.locationName),
      temperatureUnit: temperatureUnit,
      tempF: tempF,
      feelsLikeF: feelsLikeF,
      condition: current.condition,
      humidity: current.humidity,
      windMph: windMph,
      precipChance: precipChance,
      daypart: Daypart.fromDateTime(observedAt),
      tags: tags,
      conditionCode: conditionCode,
    );
  }

  String _displayTemperature(int fahrenheit) =>
      temperatureUnit == TemperatureUnit.celsius
          ? ((fahrenheit - 32) * 5 / 9).round().toString()
          : fahrenheit.toString();

  String render(String template) {
    final values = <String, String>{
      'city': city.trim().isEmpty ? 'your area' : city,
      'temp': _displayTemperature(tempF),
      'temp_unit': '°${temperatureUnit.suffix}',
      'feels_like': _displayTemperature(feelsLikeF),
      'condition': condition.trim().isEmpty ? 'weather' : condition,
      'humidity': humidity.toString(),
      'wind_mph': windMph.round().toString(),
      'precip_chance': precipChance.toString(),
      'daypart': daypart.name,
    };

    final rendered =
        template.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (match) {
      final key = match.group(1)!;
      return values[key] ?? '';
    });
    return _cleanRenderedText(rendered);
  }

  static WeatherRoastContext fallback({
    String city = 'your area',
    Daypart daypart = Daypart.any,
  }) {
    return WeatherRoastContext(
      city: city,
      tempF: 0,
      feelsLikeF: 0,
      condition: 'weather',
      humidity: 0,
      windMph: 0,
      precipChance: 0,
      daypart: daypart,
      tags: const {WeatherRoastTag.fallback},
    );
  }
}

bool _isBadAir(int aqi, String category) {
  final normalized = category.toLowerCase();
  return aqi >= 151 ||
      normalized.contains('unhealthy') ||
      normalized.contains('hazardous');
}

bool _isStorm(int? code, String condition, String main) {
  return (code != null && code >= 200 && code < 300) ||
      main.contains('thunderstorm') ||
      condition.contains('thunder') ||
      condition.contains('storm');
}

bool _isSnow(int? code, String condition, String main) {
  return (code != null && code >= 600 && code < 700) ||
      main.contains('snow') ||
      condition.contains('snow') ||
      condition.contains('sleet');
}

bool _isFog(int? code, String condition, String main) {
  const fogCodes = {701, 711, 721, 731, 741, 751, 761, 762, 771, 781};
  return (code != null && fogCodes.contains(code)) ||
      main.contains('mist') ||
      main.contains('haze') ||
      condition.contains('fog') ||
      condition.contains('mist') ||
      condition.contains('haze') ||
      condition.contains('smoke') ||
      condition.contains('dust');
}

bool _isRain(int? code, String condition, String main) {
  return (code != null && code >= 500 && code < 600) ||
      (code != null && code >= 300 && code < 400) ||
      main.contains('rain') ||
      main.contains('drizzle') ||
      condition.contains('rain') ||
      condition.contains('drizzle') ||
      condition.contains('shower');
}

bool _isHeavyRain(
  int? code,
  String condition,
  int precipChance,
  double? rainLastHour,
) {
  return (code != null && code >= 502 && code < 600) ||
      condition.contains('heavy') ||
      precipChance >= 75 ||
      (rainLastHour ?? 0) >= 0.25;
}

bool _isClear(int? code, String condition, String main) {
  return code == 800 ||
      main.contains('clear') ||
      condition.contains('clear') ||
      condition.contains('sunny');
}

bool _isPartlyCloudy(int? code, String condition) {
  return code == 801 ||
      condition.contains('partly') ||
      condition.contains('few clouds') ||
      condition.contains('mostly sunny');
}

bool _isCloudy(int? code, String condition, String main) {
  return (code != null && code >= 802 && code <= 804) ||
      main.contains('cloud') ||
      condition.contains('cloud') ||
      condition.contains('overcast');
}

bool _mentionsSevereWeather(String condition) {
  return condition.contains('severe') ||
      condition.contains('tornado') ||
      condition.contains('hurricane') ||
      condition.contains('warning');
}

String _cityName(String locationName) {
  final trimmed = locationName.trim();
  if (trimmed.isEmpty) return 'your area';
  return trimmed.split(',').first.trim();
}

String _cleanRenderedText(String text) {
  var cleaned = text
      .replaceAllMapped(
        RegExp(r'\s+([,.!?;:])'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'[,;:]\s*([.!?])'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  return cleaned;
}
