import '../models/persona.dart';
import '../models/weather_models.dart';
import '../features/roasts/controllers/local_roast_controller.dart';

/// Compatibility facade for older home/burns widgets; all choices use the same
/// local engine and never fetch content or weather during selection.
class PersonaRoastService {
  PersonaRoastService({LocalRoastController? controller})
      : controller = controller ?? LocalRoastController();
  final LocalRoastController controller;

  String getRoast(
          {required PersonaType persona,
          required WeatherBundle weather,
          bool another = false}) =>
      controller
          .select(
            persona: switch (persona) {
              PersonaType.karen => 'karen',
              PersonaType.fratBro => 'frat_bro',
              PersonaType.grandpa => 'grandpa',
              PersonaType.politician => 'politician',
              PersonaType.twoYearOld => 'two_year_old',
            },
            bundle: weather,
            another: another,
          )
          .renderedText;
}
