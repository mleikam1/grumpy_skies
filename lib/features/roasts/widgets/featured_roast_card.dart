import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';
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
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: persona.id == 'karen'
            ? colors.karenGradient
            : colors.grandpaGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: persona.id == 'karen'
                ? colors.karenBorder
                : colors.grandpaBorder),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 300 || scale > 1.35;
        final title =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEET YOUR FORECASTER',
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary)),
          const SizedBox(height: 10),
          Text('${persona.name}.',
              style: const TextStyle(
                  fontSize: 39,
                  height: 1.05,
                  letterSpacing: -1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.karenBorder)),
            child: Text(
                persona.id == 'grandpa'
                    ? 'WEATHER WISEGUY'
                    : RoastPersonas.byId(persona.id).badgeText,
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: .9,
                    fontWeight: FontWeight.w800,
                    color: colors.insightIcon)),
          ),
        ]);
        final quote = Text('“${roast.text}”',
            style: const TextStyle(
                fontSize: 21,
                height: 1.22,
                letterSpacing: -.35,
                fontWeight: FontWeight.w700));
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (narrow) ...[
                title,
                SizedBox(
                    height: 150,
                    child: DmPersonaPortrait(personaId: persona.id)),
                const SizedBox(height: 12),
                quote,
              ] else
                Stack(children: [
                  Positioned(
                      top: 0,
                      right: -12,
                      child: DmPersonaPortrait(
                          personaId: persona.id,
                          width: constraints.maxWidth * .47,
                          height: 213)),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding: EdgeInsets.only(
                                right: constraints.maxWidth * .3),
                            child: title),
                        const SizedBox(height: 24),
                        Padding(
                            padding: EdgeInsets.only(
                                right: constraints.maxWidth * .32),
                            child: quote),
                      ]),
                ]),
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
