import 'package:flutter/foundation.dart';

import '../models/temperature_unit.dart';

class SettingsController extends ChangeNotifier {
  TemperatureUnit _temperatureUnit = TemperatureUnit.fahrenheit;

  TemperatureUnit get temperatureUnit => _temperatureUnit;

  void setTemperatureUnit(TemperatureUnit unit) {
    if (unit == _temperatureUnit) return;
    _temperatureUnit = unit;
    notifyListeners();
  }
}
