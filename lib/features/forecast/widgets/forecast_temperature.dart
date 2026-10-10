import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/settings_controller.dart';
export '../../../core/weather/temperature_format.dart';

TemperatureUnit forecastTemperatureUnit(BuildContext context) =>
    context.watch<SettingsController?>()?.temperatureUnit ??
    TemperatureUnit.fahrenheit;
