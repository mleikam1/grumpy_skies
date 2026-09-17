import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/settings_controller.dart';

TemperatureUnit forecastTemperatureUnit(BuildContext context) =>
    context.watch<SettingsController?>()?.temperatureUnit ??
    TemperatureUnit.fahrenheit;

String forecastTemperature(double celsius, TemperatureUnit unit,
    {bool suffix = false}) {
  final value =
      unit == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32;
  return '${value.round()}°${suffix ? unit.suffix : ''}';
}
