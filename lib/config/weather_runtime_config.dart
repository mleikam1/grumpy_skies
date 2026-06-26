/// Conservative defaults for live weather and radar rollout.
///
/// These values are app-side defaults only. Production overrides should come
/// from Remote Config once Firebase is connected.
class WeatherRuntimeConfig {
  const WeatherRuntimeConfig._();

  static const weatherProvider = 'openweather';
  static const radarProvider = 'noaa_mrms';
  static const weatherEnabled = true;
  static const radarEnabled = true;
  static const weatherCacheCurrentMinutes = 10;
  static const weatherCacheHourlyMinutes = 30;
  static const weatherCacheDailyMinutes = 60;
  static const weatherCacheMinutePrecipMinutes = 10;
  static const radarDefaultFrameCount = 19;
  static const radarMaxFrameCount = 19;
  static const radarMinZoom = 3;
  static const radarMaxZoom = 12;
  static const radarUsOnly = true;
  static const weatherRoundLatLonPrecision = 2;
}
