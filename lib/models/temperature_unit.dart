enum TemperatureUnit { fahrenheit, celsius }

extension TemperatureUnitX on TemperatureUnit {
  String get label => this == TemperatureUnit.fahrenheit ? 'Fahrenheit' : 'Celsius';

  String get suffix => this == TemperatureUnit.fahrenheit ? 'F' : 'C';
}
