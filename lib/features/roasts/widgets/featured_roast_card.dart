import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../../shared/widgets/dm_roast_mood_badge.dart';
import '../../../shared/widgets/dm_roast_surface.dart';
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
    final colors = context.dmRoastColors;
    final mood = roast.resolvedMood;
    return DmRoastSurface(
      colors: colors,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(22),
      illuminationAlignment: const Alignment(.65, -.55),
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
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 32,
                  height: 1.08,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DmPersonaTitleBadge(
              colors: colors,
              label: persona.id == 'grandpa'
                  ? 'WEATHER WISEGUY'
                  : RoastPersonas.byId(persona.id).badgeText),
          const SizedBox(height: 10),
          DmRoastMoodBadge(mood: mood, colors: colors),
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
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 21,
                      height: 1.22,
                      letterSpacing: -.35,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Divider(color: colors.divider, height: 1),
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
