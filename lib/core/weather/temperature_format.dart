import '../../models/temperature_unit.dart';

/// Shared by forecast rows and weather-derived captions; round only after
/// converting the original Celsius value into the user's selected unit.
String forecastTemperature(double celsius, TemperatureUnit unit,
    {bool suffix = false}) {
  final value =
      unit == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32;
  return '${value.round()}°${suffix ? unit.suffix : ''}';
}
