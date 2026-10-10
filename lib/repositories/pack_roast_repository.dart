import '../data/daymaker_sample_data.dart';
import '../features/roasts/content/roast_pack_repository.dart';
import '../features/roasts/content/roast_selector.dart';
import '../features/roasts/controllers/local_roast_controller.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import 'roast_repository.dart';

/// Compatibility adapter for the approved screens. Both Today and Roasts share
/// the same local engine; reading history never selects or requests weather.
class PackRoastRepository implements RoastRepository {
  PackRoastRepository(
      {required RoastPackRepository packs,
      LocalRoastController? controller,
      DateTime Function()? clock})
      : controller = controller ?? LocalRoastController(repository: packs),
        _clock = clock ?? DateTime.now;
  final LocalRoastController controller;
  final DateTime Function() _clock;
  TemperatureUnit _unit = TemperatureUnit.fahrenheit;

  void setWeather(WeatherBundle weather, TemperatureUnit unit) {
    _unit = unit;
    controller.publishWeather(weather, weather.location ?? controller.location);
  }

  @override
  Future<List<Persona>> getPersonas() async => [
        for (final id in [
          'karen',
          'frat_bro',
          'politician',
          'grandpa',
          'two_year_old'
        ])
          RoastPersonas.byId(id).toDayMakerPersona(),
      ];
  @override
  Future<Persona> getPersona(String id) async =>
      RoastPersonas.byId(id).toDayMakerPersona();

  @override
  Future<Roast> getDailyRoast(
      {required String personaId, required String weatherSnapshotId}) async {
    await controller.initialize();
    return fromSelection(
        controller.select(persona: personaId, unit: _unit, now: _clock()),
        weatherSnapshotId: weatherSnapshotId);
  }

  Future<Roast> nextRoast(
      {required String personaId, required String weatherSnapshotId}) async {
    await controller.initialize();
    return fromSelection(
        controller.select(
            persona: personaId, unit: _unit, now: _clock(), another: true),
        weatherSnapshotId: weatherSnapshotId);
  }

  static final _presentations = Expando<Roast>();

  static Roast fromSelection(RoastSelection selection,
          {required String weatherSnapshotId}) =>
      _presentations[selection] ??= Roast(
          id: selection.id,
          personaId: selection.persona,
          weatherSnapshotId: weatherSnapshotId,
          text: selection.renderedText,
          category: selection.line.type.name,
          mood: selection.mood,
          createdAt: selection.selectedAt ??
              selection.weatherTimestamp ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          xpReward: 0,
          selection: selection);

  void recordDisplayed(Roast roast) {
    final selection = roast.selection;
    if (selection != null) controller.commitDisplayed(selection);
  }

  @override
  Future<List<Roast>> getRoastHistory({String? personaId}) async =>
      List.unmodifiable([
        for (final selection in controller.exposures)
          if (personaId == null ||
              selection.persona == RoastPersonas.normalizeId(personaId))
            fromSelection(selection,
                weatherSnapshotId:
                    selection.weatherTimestamp?.toIso8601String() ??
                        'unavailable')
      ]);
  @override
  Future<List<Achievement>> getAchievements() async =>
      DayMakerSampleData.achievements;
  @override
  Future<List<FunFeature>> getFunFeatures() async =>
      DayMakerSampleData.funFeatures;
  @override
  Future<List<MemeTemplate>> getMemeTemplates() async =>
      DayMakerSampleData.memeTemplates;
}
