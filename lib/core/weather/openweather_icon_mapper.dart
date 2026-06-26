abstract final class OpenWeatherIconMapper {
  static const String fallbackSlug = 'not-available';

  static String map({
    int? conditionId,
    String? openWeatherIconCode,
    String? conditionMain,
    String? conditionDescription,
    DateTime? forecastTime,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final isDay = resolveIsDay(
      openWeatherIconCode: openWeatherIconCode,
      forecastTime: forecastTime,
      sunrise: sunrise,
      sunset: sunset,
    );

    final slugFromId = _slugForConditionId(
      conditionId,
      isDay: isDay,
      text: _combinedText(conditionMain, conditionDescription),
    );
    if (slugFromId != null) return slugFromId;

    final slugFromIconCode = _slugForOpenWeatherIconCode(
      openWeatherIconCode,
      isDay: isDay,
    );
    if (slugFromIconCode != null) return slugFromIconCode;

    return _slugForText(
      conditionMain: conditionMain,
      conditionDescription: conditionDescription,
      isDay: isDay,
    );
  }

  static bool? resolveIsDay({
    String? openWeatherIconCode,
    DateTime? forecastTime,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    final fromIconCode = _dayFromOpenWeatherIconCode(openWeatherIconCode);
    if (fromIconCode != null) return fromIconCode;

    if (forecastTime == null || sunrise == null || sunset == null) {
      return null;
    }

    final localTime = forecastTime.toLocal();
    final daySunrise = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      sunrise.hour,
      sunrise.minute,
      sunrise.second,
      sunrise.millisecond,
      sunrise.microsecond,
    );
    var daySunset = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      sunset.hour,
      sunset.minute,
      sunset.second,
      sunset.millisecond,
      sunset.microsecond,
    );
    if (daySunset.isBefore(daySunrise)) {
      daySunset = daySunset.add(const Duration(days: 1));
    }

    return !localTime.isBefore(daySunrise) && localTime.isBefore(daySunset);
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
      final extreme = id == 202 ||
          id == 212 ||
          id == 221 ||
          id == 232 ||
          text.contains('heavy') ||
          text.contains('severe') ||
          text.contains('ragged');
      final wet = id == 200 ||
          id == 201 ||
          id == 202 ||
          id == 230 ||
          id == 231 ||
          id == 232 ||
          text.contains('rain') ||
          text.contains('drizzle');

      if (extreme && wet) {
        return _variant(
          isDay: isDay,
          day: 'thunderstorms-day-extreme-rain',
          night: 'thunderstorms-night-extreme-rain',
          neutral: 'thunderstorms-extreme-rain',
        );
      }
      if (extreme) {
        return _variant(
          isDay: isDay,
          day: 'thunderstorms-day-extreme',
          night: 'thunderstorms-night-extreme',
          neutral: 'thunderstorms-extreme',
        );
      }
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

    if (id >= 300 && id < 400) {
      return _variant(
        isDay: isDay,
        day: 'overcast-day-drizzle',
        night: 'overcast-night-drizzle',
        neutral: 'drizzle',
      );
    }

    if (id >= 500 && id < 600) {
      if (id == 511) return 'sleet';
      if (id >= 502 && id <= 504) {
        return _variant(
          isDay: isDay,
          day: 'extreme-day-rain',
          night: 'extreme-night-rain',
          neutral: 'extreme-rain',
        );
      }
      if (id >= 520) {
        return _variant(
          isDay: isDay,
          day: 'overcast-day-rain',
          night: 'overcast-night-rain',
          neutral: 'rain',
        );
      }
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day-rain',
        night: 'partly-cloudy-night-rain',
        neutral: 'rain',
      );
    }

    if (id >= 600 && id < 700) {
      if (id == 611 || id == 612 || id == 613 || id == 615 || id == 616) {
        return 'sleet';
      }
      if (id == 602) {
        return _variant(
          isDay: isDay,
          day: 'extreme-day-snow',
          night: 'extreme-night-snow',
          neutral: 'extreme-snow',
        );
      }
      if (id >= 620) {
        return _variant(
          isDay: isDay,
          day: 'overcast-day-snow',
          night: 'overcast-night-snow',
          neutral: 'snow',
        );
      }
      return _variant(
        isDay: isDay,
        day: 'partly-cloudy-day-snow',
        night: 'partly-cloudy-night-snow',
        neutral: 'snow',
      );
    }

    if (id >= 700 && id < 800) {
      return switch (id) {
        701 => 'mist',
        711 => 'smoke',
        721 => _variant(
            isDay: isDay,
            day: 'haze-day',
            night: 'haze-night',
            neutral: 'haze',
          ),
        731 || 751 || 761 || 762 => _variant(
            isDay: isDay,
            day: 'dust-day',
            night: 'dust-night',
            neutral: 'dust',
          ),
        741 => _variant(
            isDay: isDay,
            day: 'fog-day',
            night: 'fog-night',
            neutral: 'fog',
          ),
        771 => 'wind-alert',
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
        neutral: 'partly-cloudy-day',
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
          neutral: 'partly-cloudy-day',
        ),
      '03' => 'cloudy',
      '04' => _variant(
          isDay: isDay,
          day: 'overcast-day',
          night: 'overcast-night',
          neutral: 'overcast',
        ),
      '09' => _variant(
          isDay: isDay,
          day: 'overcast-day-rain',
          night: 'overcast-night-rain',
          neutral: 'rain',
        ),
      '10' => _variant(
          isDay: isDay,
          day: 'partly-cloudy-day-rain',
          night: 'partly-cloudy-night-rain',
          neutral: 'rain',
        ),
      '11' => _variant(
          isDay: isDay,
          day: 'thunderstorms-day',
          night: 'thunderstorms-night',
          neutral: 'thunderstorms',
        ),
      '13' => _variant(
          isDay: isDay,
          day: 'partly-cloudy-day-snow',
          night: 'partly-cloudy-night-snow',
          neutral: 'snow',
        ),
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
    if (text.contains('mist')) return 'mist';
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
        neutral: 'partly-cloudy-day',
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
    if (normalized == null || normalized.isEmpty) return null;
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
