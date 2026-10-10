import 'forecast_solar_context.dart';

abstract final class OpenWeatherIconMapper {
  static const String fallbackSlug = 'not-available';

  static String map({
    int? conditionId,
    String? openWeatherIconCode,
    String? conditionMain,
    String? conditionDescription,
    DateTime? forecastTime,
    DateTime? forecastLocalTime,
    double? latitude,
    double? longitude,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final isDay = resolveIsDay(
      openWeatherIconCode: openWeatherIconCode,
      forecastTime: forecastTime,
      forecastLocalTime: forecastLocalTime,
      latitude: latitude,
      longitude: longitude,
      sunrise: sunrise,
      sunset: sunset,
    );

    String withUnknownDaylight(String slug) =>
        slug == 'clear-day' && isDay == null && forecastLocalTime != null
            ? fallbackSlug
            : slug;

    final slugFromId = _slugForConditionId(
      conditionId,
      isDay: isDay,
      text: _combinedText(conditionMain, conditionDescription),
    );
    if (slugFromId != null) return withUnknownDaylight(slugFromId);

    final slugFromIconCode = _slugForOpenWeatherIconCode(
      openWeatherIconCode,
      isDay: isDay,
    );
    if (slugFromIconCode != null) return withUnknownDaylight(slugFromIconCode);

    return withUnknownDaylight(_slugForText(
      conditionMain: conditionMain,
      conditionDescription: conditionDescription,
      isDay: isDay,
    ));
  }

  static bool? resolveIsDay({
    String? openWeatherIconCode,
    DateTime? forecastTime,
    DateTime? forecastLocalTime,
    double? latitude,
    double? longitude,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final fromIconCode = _dayFromOpenWeatherIconCode(openWeatherIconCode);
    if (fromIconCode != null) return fromIconCode;

    if (forecastTime == null) return null;
    return _dayFromSolarEvents(
          forecastTime: forecastTime,
          forecastLocalTime: forecastLocalTime,
          sunrise: sunrise,
          sunset: sunset,
        ) ??
        forecastIsDaylight(
          instant: forecastTime,
          latitude: latitude,
          longitude: longitude,
        );
  }

  static bool? _dayFromSolarEvents({
    required DateTime forecastTime,
    DateTime? forecastLocalTime,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    if (sunrise == null ||
        sunset == null ||
        sunrise.millisecondsSinceEpoch <= 0 ||
        sunset.millisecondsSinceEpoch <= 0) {
      return null;
    }

    if (!sunset.isAfter(sunrise) ||
        sunset.difference(sunrise) >= const Duration(days: 1)) {
      return null;
    }

    // Compare real instants. Never project today's solar events onto a future
    // forecast date, or infer the selected city's clock from the phone timezone.
    // A local forecast timestamp can carry IANA calendar fields (or the existing
    // provider-offset wall clock) without changing the absolute target instant.
    DateTime calendarTime(DateTime instant) {
      if (forecastLocalTime == null) return instant;
      final localWallClock = DateTime.utc(
        forecastLocalTime.year,
        forecastLocalTime.month,
        forecastLocalTime.day,
        forecastLocalTime.hour,
        forecastLocalTime.minute,
        forecastLocalTime.second,
      );
      final offset = localWallClock.difference(forecastTime.toUtc());
      return instant.toUtc().add(offset);
    }

    final targetDay = calendarTime(forecastTime);
    final sunriseDay = calendarTime(sunrise);
    final sunsetDay = calendarTime(sunset);
    bool sameDay(DateTime other) =>
        targetDay.year == other.year &&
        targetDay.month == other.month &&
        targetDay.day == other.day;
    if (!sameDay(sunriseDay) || !sameDay(sunsetDay)) return null;
    return !forecastTime.isBefore(sunrise) && forecastTime.isBefore(sunset);
  }

  static String? semanticLabel({
    String? conditionMain,
    String? conditionDescription,
  }) {
    final description = conditionDescription?.trim();
    if (description != null && description.isNotEmpty) return description;

    final main = conditionMain?.trim();
    if (main != null && main.isNotEmpty) return main;

    return null;
  }

  static String? _slugForConditionId(
    int? conditionId, {
    required bool? isDay,
    required String text,
  }) {
    final id = conditionId;
    if (id == null) return null;

    if (id >= 200 && id < 300) {
      return 'thunderstorms';
    }

    if (id >= 300 && id < 400) {
      return 'drizzle';
    }

    if (id >= 500 && id < 600) {
      return 'rain';
    }

    if (id >= 600 && id < 700) {
      if (id == 611 || id == 612 || id == 613 || id == 615 || id == 616) {
        return 'sleet';
      }
      return 'snow';
    }

    if (id >= 700 && id < 800) {
      return switch (id) {
        // The package's mist is only three faint strokes; fog provides a
        // filled cloud plus moving fog layers without inventing sun or moon.
        701 => 'fog',
        711 => 'smoke',
        721 => _variant(
            isDay: isDay,
            day: 'haze-day',
            night: 'haze-night',
            neutral: 'haze',
          ),
        731 || 751 || 761 || 762 => 'dust',
        741 => _variant(
            isDay: isDay,
            day: 'fog-day',
            night: 'fog-night',
            neutral: 'fog',
          ),
        771 => 'wind',
        781 => 'tornado',
        _ => _slugForText(
            conditionMain: null,
            conditionDescription: text,
            isDay: isDay,
          ),
      };
    }

    if (id == 800) {
      return _variant(
        isDay: isDay,
        day: 'clear-day',
        night: 'clear-night',
        neutral: 'clear-day',
      );
    }

    if (id == 801 || id == 802) {
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day',
        night: 'partly-cloudy-night',
        neutral: 'cloudy',
      );
    }

    if (id == 803) return 'cloudy';

    if (id == 804) {
      return _variant(
        isDay: isDay,
        day: 'overcast-day',
        night: 'overcast-night',
        neutral: 'overcast',
      );
    }

    return null;
  }

  static String? _slugForOpenWeatherIconCode(
    String? openWeatherIconCode, {
    required bool? isDay,
  }) {
    final normalized = openWeatherIconCode?.trim().toLowerCase();
    if (normalized == null || normalized.length < 2) return null;

    return switch (normalized.substring(0, 2)) {
      '01' => _variant(
          isDay: isDay,
          day: 'clear-day',
          night: 'clear-night',
          neutral: 'clear-day',
        ),
      '02' => _variant(
          isDay: isDay,
          day: 'partly-cloudy-day',
          night: 'partly-cloudy-night',
          neutral: 'cloudy',
        ),
      '03' => 'cloudy',
      '04' => _variant(
          isDay: isDay,
          day: 'overcast-day',
          night: 'overcast-night',
          neutral: 'overcast',
        ),
      '09' => 'rain',
      '10' => 'rain',
      '11' => 'thunderstorms',
      '13' => 'snow',
      '50' => _variant(
          isDay: isDay,
          day: 'fog-day',
          night: 'fog-night',
          neutral: 'fog',
        ),
      _ => null,
    };
  }

  static String _slugForText({
    String? conditionMain,
    String? conditionDescription,
    required bool? isDay,
  }) {
    final text = _combinedText(conditionMain, conditionDescription);
    if (text.isEmpty) return fallbackSlug;

    if (text.contains('tornado')) return 'tornado';
    if (text.contains('hurricane')) return 'hurricane';
    if (text.contains('thunder') || text.contains('storm')) {
      final wet = text.contains('rain') || text.contains('drizzle');
      if (wet) {
        return _variant(
          isDay: isDay,
          day: 'thunderstorms-day-rain',
          night: 'thunderstorms-night-rain',
          neutral: 'thunderstorms-rain',
        );
      }
      return _variant(
        isDay: isDay,
        day: 'thunderstorms-day',
        night: 'thunderstorms-night',
        neutral: 'thunderstorms',
      );
    }
    if (text.contains('sleet') || text.contains('freezing')) return 'sleet';
    if (text.contains('snow')) {
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day-snow',
        night: 'partly-cloudy-night-snow',
        neutral: 'snow',
      );
    }
    if (text.contains('drizzle')) {
      return _variant(
        isDay: isDay,
        day: 'overcast-day-drizzle',
        night: 'overcast-night-drizzle',
        neutral: 'drizzle',
      );
    }
    if (text.contains('rain') || text.contains('shower')) {
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day-rain',
        night: 'partly-cloudy-night-rain',
        neutral: 'rain',
      );
    }
    if (text.contains('fog')) {
      return _variant(
        isDay: isDay,
        day: 'fog-day',
        night: 'fog-night',
        neutral: 'fog',
      );
    }
    if (text.contains('mist')) return 'fog';
    if (text.contains('smoke')) return 'smoke';
    if (text.contains('haze')) {
      return _variant(
        isDay: isDay,
        day: 'haze-day',
        night: 'haze-night',
        neutral: 'haze',
      );
    }
    if (text.contains('dust') ||
        text.contains('sand') ||
        text.contains('ash')) {
      return _variant(
        isDay: isDay,
        day: 'dust-day',
        night: 'dust-night',
        neutral: 'dust',
      );
    }
    if (text.contains('squall') || text.contains('wind')) {
      return 'wind-alert';
    }
    if (text.contains('overcast')) {
      return _variant(
        isDay: isDay,
        day: 'overcast-day',
        night: 'overcast-night',
        neutral: 'overcast',
      );
    }
    if (text.contains('cloud')) {
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day',
        night: 'partly-cloudy-night',
        neutral: 'cloudy',
      );
    }
    if (text.contains('clear') || text.contains('sun')) {
      return _variant(
        isDay: isDay,
        day: 'clear-day',
        night: 'clear-night',
        neutral: 'clear-day',
      );
    }
    if (text.contains('hot')) return 'sun-hot';

    return fallbackSlug;
  }

  static bool? _dayFromOpenWeatherIconCode(String? openWeatherIconCode) {
    final normalized = openWeatherIconCode?.trim().toLowerCase();
    if (normalized == null ||
        !RegExp(r'^(01|02|03|04|09|10|11|13|50)[dn]$').hasMatch(normalized)) {
      return null;
    }
    if (normalized.endsWith('d')) return true;
    if (normalized.endsWith('n')) return false;
    return null;
  }

  static String _variant({
    required bool? isDay,
    required String day,
    required String night,
    required String neutral,
  }) {
    return switch (isDay) {
      true => day,
      false => night,
      null => neutral,
    };
  }

  static String _combinedText(String? main, String? description) {
    return [
      if (main != null) main,
      if (description != null) description,
    ].join(' ').trim().toLowerCase();
  }
}
