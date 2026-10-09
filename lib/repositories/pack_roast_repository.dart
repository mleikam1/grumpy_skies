import '../data/daymaker_sample_data.dart';
import '../features/roasts/content/roast_pack_repository.dart';
import '../features/roasts/content/roast_selector.dart';
import '../features/roasts/content/weather_roast_models.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import 'roast_repository.dart';

/// Local editorial content, selected against the real weather bundle.
/// Catalog art/features are static; no sample weather or invented history enters
/// this repository. Selecting another line makes no weather or AI request.
class PackRoastRepository implements RoastRepository {
  PackRoastRepository(
      {required RoastPackRepository packs, DateTime Function()? clock})
      : _packs = packs,
        _clock = clock ?? DateTime.now;
  final RoastPackRepository _packs;
  final DateTime Function() _clock;
  Future<RoastPack>? _pack;
  WeatherBundle? _weather;
  TemperatureUnit _unit = TemperatureUnit.fahrenheit;
  final _daily = <String, Roast>{};
  final _recent = <String, List<String>>{};
  final _history = <Roast>[];

  void setWeather(WeatherBundle weather, TemperatureUnit unit) {
    if (_weather?.current.displayUpdatedAt !=
            weather.current.displayUpdatedAt ||
        _weather?.current.locationName != weather.current.locationName ||
        _unit != unit) {
      _daily.clear();
    }
    _weather = weather;
    _unit = unit;
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
    final id = RoastPersonas.normalizeId(personaId);
    return _daily[id] ??=
        await nextRoast(personaId: id, weatherSnapshotId: weatherSnapshotId);
  }

  Future<Roast> nextRoast(
      {required String personaId, required String weatherSnapshotId}) async {
    final weather = _weather;
    if (weather == null) {
      throw StateError('Weather is required to select a roast.');
    }
    final id = RoastPersonas.normalizeId(personaId);
    final recent = _recent.putIfAbsent(id, () => []);
    final RoastPack pack;
    try {
      pack = await (_pack ??= _packs.loadPack());
    } catch (_) {
      _pack = null;
      rethrow;
    }
    final selection = const RoastSelector().select(
      pack: pack,
      context: WeatherRoastContext.fromWeatherBundle(weather,
          temperatureUnit: _unit),
      persona: id,
      type: RoastType.today,
      recentRoastIds: recent,
      seed: '$weatherSnapshotId|$id|${recent.length}',
    );
    recent.add(selection.line.id);
    if (recent.length > 12) recent.removeAt(0);
    final roast = Roast(
        id: selection.line.id,
        personaId: id,
        weatherSnapshotId: weatherSnapshotId,
        text: selection.renderedText,
        category: selection.line.type.name,
        createdAt: _clock(),
        xpReward: 0);
    _daily[id] = roast;
    return roast;
  }

  void recordDisplayed(Roast roast) {
    if (_history.isNotEmpty &&
        _history.first.id == roast.id &&
        _history.first.text == roast.text) {
      return;
    }
    _history.insert(0, roast);
    if (_history.length > 50) _history.removeLast();
  }

  @override
  Future<List<Roast>> getRoastHistory({String? personaId}) async =>
      List.unmodifiable(_history.where((roast) =>
          personaId == null ||
          roast.personaId == RoastPersonas.normalizeId(personaId)));
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
