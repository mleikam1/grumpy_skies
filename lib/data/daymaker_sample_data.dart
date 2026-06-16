import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import '../shared/assets/dm_assets.dart';

abstract final class DayMakerSampleData {
  static final DateTime observedAt = DateTime(2026, 6, 14, 9);

  static final WeatherSnapshot weatherSnapshot = WeatherSnapshot(
    id: 'sf-partly-cloudy-2026-06-14',
    locationName: 'San Francisco, CA',
    condition: 'Partly Cloudy',
    temperatureF: 72,
    feelsLikeF: 74,
    windMph: 8,
    windDirection: 'SW',
    humidityPercent: 56,
    rainChancePercent: 38,
    aqi: 82,
    aqiCategory: 'Moderate',
    uvIndex: 5,
    uvCategory: 'Moderate',
    chaosMeterPercent: 82,
    observedAt: observedAt,
    hourly: List.unmodifiable([
      ForecastHour(
        time: DateTime(2026, 6, 14, 9),
        temperatureF: 72,
        condition: 'Partly Cloudy',
        rainChancePercent: 38,
      ),
      ForecastHour(
        time: DateTime(2026, 6, 14, 10),
        temperatureF: 73,
        condition: 'Partly Cloudy',
        rainChancePercent: 35,
      ),
      ForecastHour(
        time: DateTime(2026, 6, 14, 11),
        temperatureF: 73,
        condition: 'Partly Cloudy',
        rainChancePercent: 32,
      ),
      ForecastHour(
        time: DateTime(2026, 6, 14, 12),
        temperatureF: 74,
        condition: 'Cloudy',
        rainChancePercent: 40,
      ),
      ForecastHour(
        time: DateTime(2026, 6, 14, 13),
        temperatureF: 72,
        condition: 'Cloudy',
        rainChancePercent: 45,
      ),
      ForecastHour(
        time: DateTime(2026, 6, 14, 14),
        temperatureF: 71,
        condition: 'Partly Cloudy',
        rainChancePercent: 38,
      ),
    ]),
    daily: List.unmodifiable([
      ForecastDay(
        date: DateTime(2026, 6, 14),
        lowF: 58,
        highF: 72,
        condition: 'Partly Cloudy',
        rainChancePercent: 38,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 15),
        lowF: 57,
        highF: 70,
        condition: 'Cloudy',
        rainChancePercent: 42,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 16),
        lowF: 56,
        highF: 69,
        condition: 'AM Drizzle',
        rainChancePercent: 55,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 17),
        lowF: 58,
        highF: 73,
        condition: 'Partly Cloudy',
        rainChancePercent: 30,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 18),
        lowF: 59,
        highF: 75,
        condition: 'Mostly Sunny',
        rainChancePercent: 18,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 19),
        lowF: 60,
        highF: 74,
        condition: 'Partly Cloudy',
        rainChancePercent: 26,
      ),
      ForecastDay(
        date: DateTime(2026, 6, 20),
        lowF: 58,
        highF: 71,
        condition: 'Cloudy',
        rainChancePercent: 36,
      ),
    ]),
    metrics: const [
      WeatherMetric(
        id: 'temperature',
        label: 'Temperature',
        value: '72°F',
        detail: 'Partly Cloudy',
      ),
      WeatherMetric(
        id: 'feels-like',
        label: 'Feels like',
        value: '74°F',
      ),
      WeatherMetric(
        id: 'wind',
        label: 'Wind',
        value: '8 mph SW',
      ),
      WeatherMetric(
        id: 'humidity',
        label: 'Humidity',
        value: '56%',
      ),
      WeatherMetric(
        id: 'rain-chance',
        label: 'Rain chance',
        value: '38%',
      ),
      WeatherMetric(
        id: 'aqi',
        label: 'AQI',
        value: '82 Moderate',
      ),
      WeatherMetric(
        id: 'uv',
        label: 'UV',
        value: '5 Moderate',
      ),
      WeatherMetric(
        id: 'chaos-meter',
        label: 'Chaos Meter',
        value: '82%',
      ),
    ],
  );

  static final WeatherBundle weatherBundle =
      WeatherBundle.fromSnapshot(weatherSnapshot);

  static final Persona persona = Persona(
    id: 'karen',
    name: 'Karen',
    title: 'Roast Queen',
    avatarAsset: DmAssets.personas.karen,
    requiredXp: 0,
    unlocked: true,
  );

  static final List<Persona> personas = List.unmodifiable([
    persona,
    Persona(
      id: 'frat-bro',
      name: 'Frat Bro',
      title: 'Barometer Bro',
      avatarAsset: DmAssets.personas.fratBro,
      requiredXp: 0,
      unlocked: true,
    ),
    Persona(
      id: 'grandpa',
      name: 'Grandpa',
      title: 'Cloud Historian',
      avatarAsset: DmAssets.personas.grandpa,
      requiredXp: 0,
      unlocked: true,
    ),
    Persona(
      id: 'politician',
      name: 'Politician',
      title: 'Spin Doctor',
      avatarAsset: DmAssets.personas.politician,
      requiredXp: 0,
      unlocked: true,
    ),
    Persona(
      id: 'two-year-old',
      name: '2-Year-Old',
      title: 'Tiny Thunder',
      avatarAsset: DmAssets.personas.toddler,
      requiredXp: 0,
      unlocked: true,
    ),
  ]);

  static final Roast roast = Roast(
    id: 'sf-karen-daily-roast',
    personaId: persona.id,
    weatherSnapshotId: weatherSnapshot.id,
    text: 'It’s 72°F and somehow still making a scene.',
    category: 'daily',
    createdAt: observedAt,
    xpReward: 15,
  );

  static final List<Roast> dailyRoasts = List.unmodifiable([
    roast,
    Roast(
      id: 'sf-frat-bro-daily-roast',
      personaId: 'frat-bro',
      weatherSnapshotId: weatherSnapshot.id,
      text:
          'It’s 72°F, bro. The clouds are mid and the humidity is doing keg stands.',
      category: 'daily',
      createdAt: observedAt.subtract(const Duration(minutes: 12)),
      xpReward: 15,
    ),
    Roast(
      id: 'sf-grandpa-daily-roast',
      personaId: 'grandpa',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Back in my day, 8 mph wind was called walking to school uphill.',
      category: 'daily',
      createdAt: observedAt.subtract(const Duration(minutes: 24)),
      xpReward: 15,
    ),
    Roast(
      id: 'sf-politician-daily-roast',
      personaId: 'politician',
      weatherSnapshotId: weatherSnapshot.id,
      text:
          'We are forming a committee to investigate why 56% humidity feels personal.',
      category: 'daily',
      createdAt: observedAt.subtract(const Duration(minutes: 36)),
      xpReward: 15,
    ),
    Roast(
      id: 'sf-two-year-old-daily-roast',
      personaId: 'two-year-old',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Clouds said no nap, so now the whole sky is cranky.',
      category: 'daily',
      createdAt: observedAt.subtract(const Duration(minutes: 48)),
      xpReward: 15,
    ),
  ]);

  static final List<Roast> roastHistory = List.unmodifiable([
    roast,
    Roast(
      id: 'sf-karen-hourly-roast',
      personaId: persona.id,
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Partly cloudy with a 100% chance of asking for the manager.',
      category: 'hourly',
      createdAt: observedAt.subtract(const Duration(hours: 1)),
      xpReward: 10,
    ),
    Roast(
      id: 'sf-frat-bro-hourly-roast',
      personaId: 'frat-bro',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Wind at 8 mph: light breeze, heavy main-character energy.',
      category: 'hourly',
      createdAt: observedAt.subtract(const Duration(hours: 2)),
      xpReward: 10,
    ),
    Roast(
      id: 'sf-grandpa-hourly-roast',
      personaId: 'grandpa',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Humidity at 56% and everyone acts like the sky invented problems.',
      category: 'hourly',
      createdAt: observedAt.subtract(const Duration(hours: 3)),
      xpReward: 10,
    ),
    Roast(
      id: 'sf-politician-hourly-roast',
      personaId: 'politician',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'The forecast is committed to transparency, except for the sun.',
      category: 'hourly',
      createdAt: observedAt.subtract(const Duration(hours: 4)),
      xpReward: 10,
    ),
    Roast(
      id: 'sf-two-year-old-hourly-roast',
      personaId: 'two-year-old',
      weatherSnapshotId: weatherSnapshot.id,
      text: 'Rain chance is 38%, which is also the chance of sharing snacks.',
      category: 'hourly',
      createdAt: observedAt.subtract(const Duration(hours: 5)),
      xpReward: 10,
    ),
  ]);

  static final List<Achievement> achievements = List.unmodifiable([
    const Achievement(
      id: 'first-roast',
      name: 'First Roast',
      description: 'Survived your first weather insult.',
      xpReward: 50,
      unlocked: true,
      progress: 1,
      target: 1,
    ),
    const Achievement(
      id: 'five-day-streak',
      name: 'Five-Day Streak',
      description: 'Checked the forecast five days in a row.',
      xpReward: 100,
      unlocked: true,
      progress: 5,
      target: 5,
    ),
    const Achievement(
      id: 'chaos-connoisseur',
      name: 'Chaos Connoisseur',
      description: 'Reached an 82% Chaos Meter day.',
      xpReward: 82,
      unlocked: true,
      progress: 82,
      target: 82,
    ),
  ]);

  static final List<FunFeature> funFeatures = List.unmodifiable([
    const FunFeature(
      id: 'chaos-meter',
      name: 'Chaos Meter',
      prompt: 'How dramatic is today?',
      value: '82%',
      enabled: true,
    ),
    const FunFeature(
      id: 'weather-fortune',
      name: 'Weather Fortune Cookie',
      prompt: 'Tiny prophecy, big attitude.',
      value: 'Today is 82% chaos. Dress accordingly.',
      enabled: true,
    ),
    const FunFeature(
      id: 'daily-poll',
      name: 'Daily Weather Poll',
      prompt: 'Would you rather sweat or freeze?',
      value: 'Sweat',
      enabled: true,
    ),
  ]);

  static final List<MemeTemplate> memeTemplates = List.unmodifiable([
    MemeTemplate(
      id: 'partly-cloudy-scene',
      name: 'Making A Scene',
      imageAsset: DmAssets.memeBackgrounds.sunny,
      topText: 'IT IS 72°F',
      bottomText: 'AND STILL MAKING A SCENE',
    ),
    MemeTemplate(
      id: 'moderate-air',
      name: 'Moderate Air',
      imageAsset: DmAssets.memeBackgrounds.office,
      topText: 'AQI 82',
      bottomText: 'THE AIR HAS NOTES',
    ),
  ]);

  static final List<RadarAlert> radarAlerts = List.unmodifiable([
    RadarAlert(
      id: 'sf-light-rain-window',
      locationName: weatherSnapshot.locationName,
      title: 'Light Rain Window',
      message: '38% chance of drizzle trying to become everyone’s problem.',
      severity: 'moderate',
      startsAt: observedAt.add(const Duration(hours: 3)),
      expiresAt: observedAt.add(const Duration(hours: 6)),
    ),
  ]);

  static const UserSettings userSettings = UserSettings(
    temperatureUnit: TemperatureUnit.fahrenheit,
    selectedPersonaId: 'karen',
    notificationsEnabled: true,
    adsEnabled: true,
    xp: 420,
    level: 3,
    streakDays: 5,
  );
}
