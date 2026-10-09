import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../../shared/widgets/dm_roast_mood_badge.dart';
import '../models/roast_persona.dart';

class FeaturedRoastCard extends StatelessWidget {
  const FeaturedRoastCard(
      {super.key,
      required this.persona,
      required this.roast,
      required this.weather,
      this.temperatureUnit = TemperatureUnit.fahrenheit});
  final Persona persona;
  final Roast roast;
  final WeatherBundle weather;
  final TemperatureUnit temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    final mood = roast.resolvedMood;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: persona.id == 'karen' || persona.id == 'two_year_old'
            ? colors.karenGradient
            : colors.grandpaGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: persona.id == 'karen'
                ? colors.karenBorder
                : colors.grandpaBorder),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final large = constraints.maxWidth < 275 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        final title =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEET YOUR FORECASTER',
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary)),
          const SizedBox(height: 10),
          Text('${persona.name}.',
              style: const TextStyle(
                  fontSize: 32,
                  height: 1.08,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DmPersonaTitleBadge(
              label: persona.id == 'grandpa'
                  ? 'WEATHER WISEGUY'
                  : RoastPersonas.byId(persona.id).badgeText),
          const SizedBox(height: 10),
          DmRoastMoodBadge(mood: mood),
        ]);
        final portrait = DmPersonaPortrait(
            personaId: persona.id,
            mood: mood,
            height: large ? 155 : 180,
            width: large ? null : constraints.maxWidth * .43);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (large) ...[title, const SizedBox(height: 10), portrait] else
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  portrait,
                ]),
              const SizedBox(height: 16),
              Text('“${roast.text}”',
                  style: const TextStyle(
                      fontSize: 21,
                      height: 1.22,
                      letterSpacing: -.35,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Divider(color: colors.grandpaBorder, height: 1),
              const SizedBox(height: 12),
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                        '${(temperatureUnit == TemperatureUnit.celsius ? weather.current.temperatureC : weather.current.temperatureF).round()}° · ${weather.current.condition}',
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary)),
                    Text(weather.current.locationName,
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary)),
                  ]),
            ]);
      }),
    );
  }
}
