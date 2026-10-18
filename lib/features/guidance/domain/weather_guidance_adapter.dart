import 'package:timezone/timezone.dart' as tz;

import '../../../models/weather_models.dart';
import 'guidance_evidence.dart';

/// Reads already loaded DTOs only. No repository, service or platform access.
class GuidanceWeatherAdapter {
  const GuidanceWeatherAdapter();

  static WeatherEvidence fromBundle(WeatherBundle bundle,
      {required GuidanceLocation location}) {
    final current = bundle.current;
    final sourceTime = current.sourceUpdatedAt;
    final intervalAnchor =
        sourceTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final currentInterval = GuidanceInterval(
        intervalAnchor, intervalAnchor.add(const Duration(minutes: 30)));
    // Actual provider coordinates outrank a requested/display location label.
    final providerHasPoint =
        current.latitude != null && current.longitude != null;
    final sourceLat =
        providerHasPoint ? current.latitude : bundle.location?.lat;
    final sourceLon =
        providerHasPoint ? current.longitude : bundle.location?.lon;
    final matched = location.latitude == null ||
        location.longitude == null ||
        (sourceLat != null &&
            sourceLon != null &&
            (sourceLat - location.latitude!).abs() < .02 &&
            (sourceLon - location.longitude!).abs() < .02);
    final forecastProvider = switch (bundle.forecastSource) {
      'nws_api' => 'National Weather Service',
      'openweather_onecall_3' ||
      'openweather_onecall_4_timelines' ||
      'openweather_legacy_2_5' =>
        'OpenWeather',
      _ => 'Existing weather service (provider not retained)',
    };
    EvidenceField<Object> field(GuidanceField key, Object? value, String unit,
            GuidanceInterval interval,
            {bool forecast = false,
            String? provider,
            EvidenceAvailability? availability}) =>
        EvidenceField<Object>(
          field: key,
          value: value,
          unit: unit,
          provider: provider ?? (forecast ? forecastProvider : 'OpenWeather'),
          kind: forecast ? EvidenceKind.forecast : EvidenceKind.observation,
          location: location,
          interval: interval,
          sourceTime: sourceTime,
          fetchedAt: current.fetchedAt,
          sourcePrecision: forecast
              ? 'forecast interval at point'
              : 'current conditions at point',
          timestampMeaning: forecast
              ? 'bundle observation anchor; forecast issue time unavailable'
              : 'provider observation',
          availability: !bundle.guidanceAvailabilityVerified
              ? EvidenceAvailability.unsupported
              : availability ??
                  (value == null
                      ? EvidenceAvailability.missing
                      : EvidenceAvailability.available),
        );
    List<EvidenceField<Object>> conditions(int? code, GuidanceInterval interval,
        {bool forecast = false, String? description}) {
      final text = (description ?? '').toLowerCase();
      // NWS aliases lose freezing/sleet and intensity; retained text restores
      // only explicit categories, never rain intensity from synthetic code 500.
      final nws = forecast && bundle.forecastSource == 'nws_api';
      final freezing = RegExp(r'freezing (rain|drizzle)|ice pellets|\bsleet\b')
          .hasMatch(text);
      final mixed = !freezing && text.contains('rain') && text.contains('snow');
      final type = freezing
          ? PrecipitationType.freezing
          : mixed
              ? PrecipitationType.mixed
              : precipitationTypeForCode(code);
      final classifiedCode = nws && text.contains('fog') ? 741 : code;
      return [
        field(GuidanceField.conditionCode, classifiedCode,
            'normalized weather condition code', interval,
            forecast: forecast),
        field(GuidanceField.precipitationType, type, 'precipitation type',
            interval,
            forecast: forecast),
        field(
            GuidanceField.severeHazard,
            code == null && !freezing
                ? null
                : freezing ||
                    (code != null && _dangerousCode(code)) ||
                    (nws && text.contains('blizzard')),
            'condition hazard flag',
            interval,
            forecast: forecast),
        field(
            GuidanceField.rainIntensity,
            forecast && forecastProvider != 'OpenWeather'
                ? null
                : rainIntensityForCode(code),
            'provider qualitative intensity',
            interval,
            forecast: forecast),
      ];
    }

    final currentFields = <EvidenceField<Object>>[
      field(
          GuidanceField.temperatureC,
          current.temperatureKnown ? current.temperatureC : null,
          '°C',
          currentInterval),
      field(
          GuidanceField.feelsLikeC,
          current.feelsLikeKnown ? current.feelsLikeC : null,
          '°C',
          currentInterval),
      field(
          GuidanceField.humidityPercent,
          current.humidityKnown ? current.humidity : null,
          '%',
          currentInterval),
      field(GuidanceField.dewPointC, current.dewPointC, '°C', currentInterval),
      field(GuidanceField.windKph, current.windKnown ? current.windKph : null,
          'km/h', currentInterval),
      field(
          GuidanceField.gustKph, current.windGustKph, 'km/h', currentInterval),
      field(GuidanceField.visibilityMeters, current.visibilityMeters, 'm',
          currentInterval),
      field(
          GuidanceField.rainMillimeters,
          current.rainLastHour == null
              ? null
              : current.rainLastHour! *
                  (current.units == 'imperial' ? 25.4 : 1),
          'mm in preceding hour',
          currentInterval),
      // Current POP is absent in the real DTO. Do not turn its default 0 into evidence.
      field(GuidanceField.precipitationProbability, null, 'fraction',
          currentInterval),
      field(
          GuidanceField.uvIndex,
          current.uvKnown &&
                  current.uvIndex >= 0 &&
                  current.sourceUpdatedAt != null
              ? current.uvIndex
              : null,
          'UV Index',
          currentInterval),
      // AQI source observation/coverage is not retained by the production DTO.
      // A current weather timestamp cannot establish the separate AQI's freshness.
      field(GuidanceField.aqi, null, current.aqiScale ?? 'unknown AQI scheme',
          currentInterval,
          provider: current.aqiSource ?? 'unknown AQI provider',
          availability: EvidenceAvailability.unsupported),
      ...conditions(current.weatherId, currentInterval,
          description: current.condition),
    ];
    if (current.sunriseKnown &&
        current.sunsetKnown &&
        sourceTime != null &&
        !sourceTime.isBefore(current.sunrise) &&
        sourceTime.isBefore(current.sunset)) {
      currentFields.add(field(GuidanceField.daylight, true,
          'daylight at observation', currentInterval));
    } else if (current.weatherIcon?.endsWith('n') == true) {
      currentFields.add(field(GuidanceField.daylight, false,
          'provider night condition', currentInterval));
    }
    final timeline = {
      for (final item in bundle.timeline) item.time.toUtc(): item
    };
    final hourly = bundle.hourly.map((hour) {
      final interval =
          GuidanceInterval(hour.time, hour.time.add(const Duration(hours: 1)));
      final detail = timeline[hour.time.toUtc()];
      // TimelineWeatherPoint retains raw provider windSpeed under windMph.
      // Its DTO uses the bundle's requested units, unlike CurrentWeather's kph.
      final wind = detail?.windMph;
      final windKph = wind == null
          ? null
          : wind * (current.units == 'imperial' ? 1.609344 : 3.6);
      final localHour = location.localTime(hour.time);
      final localSunset = location.localTime(current.sunset);
      final matchingSunset = current.sunsetKnown &&
          localHour != null &&
          localSunset != null &&
          localHour.year == localSunset.year &&
          localHour.month == localSunset.month &&
          localHour.day == localSunset.day;
      return WeatherEvidencePeriod(interval: interval, fields: [
        field(
            GuidanceField.sunset,
            matchingSunset ? current.sunset.toUtc() : null,
            'UTC instant',
            interval,
            forecast: true),
        field(GuidanceField.temperatureC,
            hour.temperatureKnown ? hour.temperatureC : null, '°C', interval,
            forecast: true),
        field(
            GuidanceField.precipitationProbability,
            hour.precipitationChanceKnown
                ? normalizeProbability(hour.precipitationChance, percent: true)
                : null,
            'fraction',
            interval,
            forecast: true),
        field(GuidanceField.windKph, windKph, 'km/h', interval, forecast: true),
        field(GuidanceField.humidityPercent, detail?.humidity, '%', interval,
            forecast: true),
        field(
            GuidanceField.daylight,
            hour.weatherIcon?.endsWith('n') == true
                ? false
                : hour.weatherIcon?.endsWith('d') == true
                    ? true
                    : null,
            'provider day/night condition',
            interval,
            forecast: true),
        ...conditions(hour.weatherId, interval,
            forecast: true, description: hour.condition),
      ]);
    }).toList();
    final daily = <WeatherEvidencePeriod>[];
    for (final day in bundle.daily) {
      final local = location.localTime(day.date);
      if (local is! tz.TZDateTime) continue;
      // DailyForecast.date is a civil date already normalized by the backend client.
      final start = tz.TZDateTime(
          local.location, day.date.year, day.date.month, day.date.day);
      final end = tz.TZDateTime(
          local.location, day.date.year, day.date.month, day.date.day + 1);
      final interval = GuidanceInterval(start.toUtc(), end.toUtc());
      daily.add(WeatherEvidencePeriod(interval: interval, daily: true, fields: [
        field(
            GuidanceField.temperatureC,
            day.temperatureKnown ? day.maxTempC : null,
            '°C daily maximum',
            interval,
            forecast: true),
        field(
            GuidanceField.lowTemperatureC,
            day.temperatureKnown ? day.minTempC : null,
            '°C daily minimum',
            interval,
            forecast: true),
        field(
            GuidanceField.precipitationProbability,
            day.precipitationChanceKnown
                ? normalizeProbability(day.precipitationChance, percent: true)
                : null,
            'fraction for day',
            interval,
            forecast: true),
        ...conditions(day.weatherId, interval,
            forecast: true, description: day.condition),
      ]));
    }
    return WeatherEvidence(
      location: location,
      locationMatched: matched,
      current: WeatherEvidencePeriod(
          interval: currentInterval, fields: currentFields),
      hourly: hourly,
      daily: daily,
      alertCoverageVerified: bundle.alertCoverageVerified,
      alertsCheckedAt: bundle.alertsCheckedAt,
      alerts: bundle.alerts.map((alert) => GuidanceAlert(
            id: guidanceFingerprint(
                '${alert.event}|${alert.senderName}|${alert.start}|${alert.end}|${alert.description}'),
            event: alert.event,
            issuer: alert.senderName,
            description: alert.description,
            location: location,
            interval: GuidanceInterval(alert.start ?? intervalAnchor,
                alert.end ?? intervalAnchor.add(const Duration(minutes: 10))),
            checkedAt: bundle.alertsCheckedAt,
            instructions: alert.instructions,
            area: alert.area,
            severity: alert.severity,
          )),
    );
  }

  static PrecipitationType precipitationTypeForCode(int? code) =>
      switch (code) {
        511 || 611 || 612 || 613 => PrecipitationType.freezing,
        615 || 616 => PrecipitationType.mixed,
        final int value when value >= 600 && value <= 622 =>
          PrecipitationType.snow,
        final int value
            when (value >= 300 && value <= 321) ||
                (value >= 500 && value <= 531) =>
          PrecipitationType.liquidRain,
        final int value when value >= 800 && value <= 804 =>
          PrecipitationType.none,
        _ => PrecipitationType.unknown,
      };
  static RainIntensity rainIntensityForCode(int? code) => switch (code) {
        300 || 310 || 500 || 520 => RainIntensity.light,
        301 || 311 || 501 || 521 => RainIntensity.moderate,
        302 || 312 || 502 || 503 || 504 || 522 || 531 => RainIntensity.heavy,
        _ => RainIntensity.unknown,
      };
  static bool _dangerousCode(int code) =>
      (code >= 200 && code < 300) ||
      const {511, 611, 612, 613, 711, 762, 771, 781}.contains(code);
}
