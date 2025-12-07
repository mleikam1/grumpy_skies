import 'dart:math';

import '../models/persona.dart';
import '../models/weather_models.dart';

class PersonaRoastService {
  final _random = Random();

  String getRoast({
    required PersonaType persona,
    required WeatherBundle weather,
  }) {
    final current = weather.current;

    final options = [
      _humidityRoast(persona, current.humidity),
      _aqiRoast(persona, current.aqi),
      _precipRoast(persona, current.precipitationChance),
      _feelsLikeRoast(persona, current.feelsLikeC),
      _sunriseRoast(persona, current.sunrise),
      _sunsetRoast(persona, current.sunset),
      _moonRoast(persona, current.moonrise, current.moonset),
    ].whereType<String>().toList();

    if (options.isEmpty) {
      options.add(_defaultRoast(persona, current.temperatureC));
    }

    return options[_random.nextInt(options.length)];
  }

  String _defaultRoast(PersonaType persona, double tempC) {
    final tempF = _cToF(tempC).toStringAsFixed(0);
    switch (persona) {
      case PersonaType.karen:
        return "It's $tempF°F and still not meeting my standards.";
      case PersonaType.fratBro:
        return "$tempF°F? Still down to grill, bro.";
      case PersonaType.grandpa:
        return "Back in my day, $tempF°F meant we kept quiet and layered up.";
      case PersonaType.politician:
        return "The temperature is $tempF°F and totally under control.";
      case PersonaType.toddler:
        return "$tempF°F. Sky feels weird. Snack time.";
    }
  }

  String? _humidityRoast(PersonaType persona, int humidity) {
    if (humidity <= 80) return null;
    final value = '$humidity%';
    switch (persona) {
      case PersonaType.karen:
        return "Humidity this high should be illegal. Fix it. ($value)";
      case PersonaType.fratBro:
        return "Air's so thick you could bench press it. ($value)";
      case PersonaType.toddler:
        return "Sky sticky. Don’t like it. ($value)";
      case PersonaType.grandpa:
        return "Reminds me of the great damp of ’72. ($value)";
      case PersonaType.politician:
        return "The humidity is stable… enough. Probably. ($value)";
    }
  }

  String? _aqiRoast(PersonaType persona, int aqi) {
    if (aqi < 100) return null;
    final level = aqi.toString();
    switch (persona) {
      case PersonaType.karen:
        return "AQI $level? I demand a recall on this air.";
      case PersonaType.fratBro:
        return "AQI $level – lungs are doing two-a-days, bro.";
      case PersonaType.grandpa:
        return "AQI at $level. I've breathed worse, but this is rude.";
      case PersonaType.politician:
        return "AQI $level is simply a temporary inconvenience.";
      case PersonaType.toddler:
        return "Air yucky. Number $level. I pout.";
    }
  }

  String? _precipRoast(PersonaType persona, int precipitationChance) {
    if (precipitationChance < 50) return null;
    final value = '$precipitationChance%';
    switch (persona) {
      case PersonaType.karen:
        return "There's a $value chance of rain ruining everything.";
      case PersonaType.fratBro:
        return "$value rain odds – still tailgating, bring a tarp.";
      case PersonaType.grandpa:
        return "$value chance of rain. Grab your coat like we used to.";
      case PersonaType.politician:
        return "With a $value precipitation probability, I recommend umbrellas.";
      case PersonaType.toddler:
        return "$value rain. Boots on. Puddles now.";
    }
  }

  String? _feelsLikeRoast(PersonaType persona, double feelsLikeC) {
    final feelsLikeF = _cToF(feelsLikeC);
    if (feelsLikeF > 90) {
      switch (persona) {
        case PersonaType.karen:
          return "Feels like ${feelsLikeF.toStringAsFixed(0)}°F – unacceptable sauna.";
        case PersonaType.fratBro:
          return "${feelsLikeF.toStringAsFixed(0)}°F feels like gains? More like meltdown.";
        case PersonaType.grandpa:
          return "Feels like ${feelsLikeF.toStringAsFixed(0)}°F. Too hot for common sense.";
        case PersonaType.politician:
          return "The feels-like is ${feelsLikeF.toStringAsFixed(0)}°F. We are monitoring.";
        case PersonaType.toddler:
          return "Feels ${feelsLikeF.toStringAsFixed(0)}. Too hot. Nap.";
      }
    }

    if (feelsLikeF < 40) {
      switch (persona) {
        case PersonaType.karen:
          return "Feels like ${feelsLikeF.toStringAsFixed(0)}°F – I didn't sign up for this freezer.";
        case PersonaType.fratBro:
          return "${feelsLikeF.toStringAsFixed(0)}°F? Cold plunge vibes only.";
        case PersonaType.grandpa:
          return "Feels like ${feelsLikeF.toStringAsFixed(0)}°F. Layer up, rookie.";
        case PersonaType.politician:
          return "Perceived temperature: ${feelsLikeF.toStringAsFixed(0)}°F. Situation fluid.";
        case PersonaType.toddler:
          return "Feels ${feelsLikeF.toStringAsFixed(0)}. Need blanket.";
      }
    }

    return null;
  }

  String? _sunriseRoast(PersonaType persona, DateTime sunrise) {
    if (sunrise.hour < 6) return null;
    final timeString = _formatTime(sunrise);
    switch (persona) {
      case PersonaType.karen:
        return "Sunrise at $timeString? Even the sun is lazy.";
      case PersonaType.fratBro:
        return "Sun's clocked in at $timeString. Same, bro.";
      case PersonaType.grandpa:
        return "Sunrise $timeString. We used to wake with the sun, not after it.";
      case PersonaType.politician:
        return "Sunrise scheduled for $timeString. We're spinning it as intentional.";
      case PersonaType.toddler:
        return "Sun wake at $timeString. Too late.";
    }
  }

  String? _sunsetRoast(PersonaType persona, DateTime sunset) {
    if (sunset.hour < 19) return null;
    final timeString = _formatTime(sunset);
    switch (persona) {
      case PersonaType.karen:
        return "Sun sets at $timeString. Prime time to complain loudly.";
      case PersonaType.fratBro:
        return "Sunset $timeString – golden hour flex inbound.";
      case PersonaType.grandpa:
        return "Sunset at $timeString. We used to respect early nights.";
      case PersonaType.politician:
        return "Expect sunset around $timeString. It's within acceptable margins.";
      case PersonaType.toddler:
        return "Sun bye-bye at $timeString. Bedtime? No.";
    }
  }

  String? _moonRoast(
    PersonaType persona,
    DateTime moonrise,
    DateTime moonset,
  ) {
    final now = DateTime.now();
    final moonriseSoon = moonrise.isAfter(now) && moonrise.difference(now).inHours <= 4;
    final moonsetLate = moonset.hour >= 7 && moonset.hour <= 9;

    if (!moonriseSoon && !moonsetLate) return null;

    if (moonriseSoon) {
      final timeString = _formatTime(moonrise);
      switch (persona) {
        case PersonaType.karen:
          return "Moonrise at $timeString? Even the moon is running on vibes.";
        case PersonaType.fratBro:
          return "Moon pops at $timeString. Night lift session confirmed.";
        case PersonaType.grandpa:
          return "Moonrise $timeString. Stars used to show up earlier.";
        case PersonaType.politician:
          return "Moonrise projected for $timeString. We support lunar transparency.";
        case PersonaType.toddler:
          return "Moon wake at $timeString. Sparkly!";
      }
    }

    final timeString = _formatTime(moonset);
    switch (persona) {
      case PersonaType.karen:
        return "Moonset dragging until $timeString. Even the sky won't clock out.";
      case PersonaType.fratBro:
        return "Moon setting at $timeString – last call for werewolves, bro.";
      case PersonaType.grandpa:
        return "Moonset $timeString. Night's overstaying its welcome.";
      case PersonaType.politician:
        return "Moonset around $timeString. An orderly transition of power.";
      case PersonaType.toddler:
        return "Moon sleep at $timeString. Night-night.";
    }
  }

  String _formatTime(DateTime time) {
    final hours = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minutes = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hours:$minutes $suffix';
  }

  double _cToF(double tempC) => tempC * 9 / 5 + 32;
}
