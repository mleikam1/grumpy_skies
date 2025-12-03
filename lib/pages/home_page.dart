import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../models/persona.dart';
import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import '../services/persona_roast_service.dart';
import '../widgets/persona_roast_bubble.dart';
import '../widgets/weather_summary_card.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Duration _roastCooldown = const Duration(seconds: 6);
  final Random _random = Random();

  int _selectedIndex = 0;
  WeatherBundle? _weather;
  bool _loading = false;
  String? _error;
  PersonaType _persona = PersonaType.karen;
  String? _currentRoast;
  List<String> _roastHistory = [];
  bool _roastCoolingDown = false;
  Timer? _cooldownTimer;
  String _fortune = 'Today is 82% chaos. Enjoy the ride.';
  String _pollChoice = '';
  String _gremlinPersona = '??';
  String _chaosMeter = '82%';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _loadWeather();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = context.read<WeatherRepository>();
      const lat = 37.7749;
      const lon = -122.4194;
      final data = await repo.getWeather(
        latitude: lat,
        longitude: lon,
        forceRefresh: force,
      );
      final roastService = context.read<PersonaRoastService>();
      final roast = roastService.getRoast(persona: _persona, weather: data);

      setState(() {
        _weather = data;
        _currentRoast = roast;
        _roastHistory = ['Today: $roast'];
        _chaosMeter = '${(60 + _random.nextInt(41)).toString()}%';
        _fortune = _randomFortune();
        _gremlinPersona = _randomGremlin();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load weather: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _refreshRoast(PersonaRoastService roastService) {
    if (_weather == null || _roastCoolingDown) return;

    final roast = roastService.getRoast(persona: _persona, weather: _weather!);
    final timestamp = TimeOfDay.now().format(context);

    setState(() {
      _currentRoast = roast;
      _roastHistory = ['[$timestamp] $roast', ..._roastHistory];
      _roastCoolingDown = true;
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_roastCooldown, () {
      if (mounted) {
        setState(() => _roastCoolingDown = false);
      }
    });
  }

  Future<void> _copyRoastLink() async {
    if (_currentRoast == null) return;
    final link =
        'https://grumpyskies.app/roast?persona=${_persona.name}&text=${Uri.encodeComponent(_currentRoast!)}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Roast link copied. Go spread the grump.')),
    );
  }

  void _goToRadarTab() {
    setState(() => _selectedIndex = 2);
  }

  String _appBarTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Roasts';
      case 2:
        return 'Radar';
      case 3:
        return 'Fun';
      case 4:
        return 'Settings';
      default:
        return 'Forecast';
    }
  }

  String _annoyanceLabel(double score) {
    if (score > 0.75) return 'Peak annoyance. Proceed with caution.';
    if (score > 0.5) return 'Mild rage simmering.';
    if (score > 0.25) return 'Snark levels stable.';
    return 'Shockingly tolerable.';
  }

  double _annoyanceScore(WeatherBundle weather) {
    final temp = weather.current.temperatureF;
    final humidity = weather.current.humidity.toDouble();
    final wind = weather.current.windKph;
    final tempPenalty = (temp - 68).abs() / 80;
    final humidityPenalty = humidity / 200;
    final windPenalty = wind / 80;
    return (tempPenalty + humidityPenalty + windPenalty).clamp(0.0, 1.0);
  }

  String _randomFortune() {
    const fortunes = [
      'Your umbrella will betray you right when drizzle turns to downpour.',
      'Today is 82% chaos. Dress accordingly.',
      'A stranger will comment on the humidity. Roll your eyes proudly.',
      'Clouds are judging your outfit. Pretend not to notice.',
      'Pretend you love this weather and maybe it will behave.',
    ];
    return fortunes[_random.nextInt(fortunes.length)];
  }

  String _randomGremlin() {
    const gremlins = [
      'Sunburned gremlin who forgot sunscreen',
      'Perpetually damp drizzle goblin',
      'Wind-whipped hair gremlin',
      'Thunder clap drama queen',
      'Air-conditioning denier',
    ];
    return gremlins[_random.nextInt(gremlins.length)];
  }

  String _randomChaosPrediction() {
    final chaos = 50 + _random.nextInt(51);
    return '$chaos% chance of accidental chaos.';
  }

  @override
  Widget build(BuildContext context) {
    final roastService = context.read<PersonaRoastService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Grumpy Skies · ${_appBarTitle()}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildForecastTab(roastService),
            _buildRoastsTab(roastService),
            _buildRadarTab(),
            _buildFunTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: GNav(
            gap: 8,
            padding: const EdgeInsets.all(12),
            backgroundColor: Colors.transparent,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            activeColor: Theme.of(context).colorScheme.onSecondaryContainer,
            tabBackgroundColor:
                Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.9),
            selectedIndex: _selectedIndex,
            onTabChange: _onTabChange,
            tabs: const [
              GButton(
                icon: Icons.wb_cloudy_outlined,
                text: 'Forecast',
                leading: Text('🌤️', style: TextStyle(fontSize: 18)),
              ),
              GButton(
                icon: Icons.whatshot_outlined,
                text: 'Roasts',
                leading: Text('🔥', style: TextStyle(fontSize: 18)),
              ),
              GButton(
                icon: Icons.radar,
                text: 'Radar',
                leading: Text('🌀', style: TextStyle(fontSize: 18)),
              ),
              GButton(
                icon: Icons.emoji_emotions_outlined,
                text: 'Fun',
                leading: Text('🎮', style: TextStyle(fontSize: 18)),
              ),
              GButton(
                icon: Icons.settings_outlined,
                text: 'Settings',
                leading: Text('⚙️', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastTab(PersonaRoastService roastService) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _loadWeather(force: true),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(_error!)),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: () => _loadWeather(force: true),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    if (_weather == null) {
      return RefreshIndicator(
        onRefresh: () => _loadWeather(force: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No weather yet. Pull to refresh.')),
          ],
        ),
      );
    }

    final annoyanceScore = _annoyanceScore(_weather!);
    final roast = _currentRoast ??
        roastService.getRoast(persona: _persona, weather: _weather!);

    return RefreshIndicator(
      onRefresh: () => _loadWeather(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WeatherSummaryCard(weather: _weather!),
          const SizedBox(height: 16),
          _buildAnnoyanceMeter(annoyanceScore),
          const SizedBox(height: 16),
          _buildPersonaSelector(),
          PersonaRoastBubble(
            personaName: _persona.displayName,
            roast: roast,
          ),
          const SizedBox(height: 16),
          _buildHourlyForecast(),
          const SizedBox(height: 16),
          _buildDailyForecast(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToRadarTab,
                  icon: const Icon(Icons.radar),
                  label: const Text('Radar quick-access'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memeGenerator,
                  ),
                  icon: const Icon(Icons.mood),
                  label: const Text('Meme Maker'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoastsTab(PersonaRoastService roastService) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Signature Grumpy Roasts',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _buildPersonaSelector(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily roast for today',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentRoast ??
                      (_weather != null
                          ? roastService.getRoast(
                              persona: _persona, weather: _weather!)
                          : 'Load weather to unlock the snark.'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _weather == null || _roastCoolingDown
                          ? null
                          : () => _refreshRoast(roastService),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _roastCoolingDown
                            ? 'Cooling down...'
                            : 'Refresh roast',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _currentRoast == null ? null : _copyRoastLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Save/share roast'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Persona selector'),
          subtitle: const Text(
            'Swap between Karen, Grandpa, Frat Bro, Politician, and Toddler.',
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Roast history'),
          subtitle: Text(
            _roastHistory.isEmpty
                ? 'No roasts yet. Tap refresh to start the chaos.'
                : _roastHistory.join('\n'),
          ),
        ),
      ],
    );
  }

  Widget _buildRadarTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondaryContainer,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'RainViewer radar (live)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: Text('🌀 Radar preview placeholder'),
                ),
                Spacer(),
                Text('• Real-time radar'),
                Text('• Storm projections'),
                Text('• Lightning alerts'),
                Text('• FutureCast radar'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.auto_graph),
          title: const Text('Storm projections'),
          subtitle: Text('Chaos meter: $_chaosMeter chance of drama.'),
        ),
        ListTile(
          leading: const Icon(Icons.bolt),
          title: const Text('Lightning alerts'),
          subtitle: const Text('If Mother Nature rages, we yell at you first.'),
        ),
        ListTile(
          leading: const Icon(Icons.timeline),
          title: const Text('FutureCast radar'),
          subtitle: Text(_randomChaosPrediction()),
        ),
      ],
    );
  }

  Widget _buildFunTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Text('🍪', style: TextStyle(fontSize: 24)),
            title: const Text('Weather Fortune Cookie'),
            subtitle: Text(_fortune),
            trailing: IconButton(
              icon: const Icon(Icons.casino),
              onPressed: () => setState(() => _fortune = _randomFortune()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('📊', style: TextStyle(fontSize: 24)),
            title: const Text('Daily Weather Poll'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Would you rather sweat or freeze?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Sweat'),
                      selected: _pollChoice == 'Sweat',
                      onSelected: (_) => setState(() => _pollChoice = 'Sweat'),
                    ),
                    ChoiceChip(
                      label: const Text('Freeze'),
                      selected: _pollChoice == 'Freeze',
                      onSelected: (_) => setState(() => _pollChoice = 'Freeze'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('🎲', style: TextStyle(fontSize: 24)),
            title: const Text('Crazy Day Predictor'),
            subtitle: Text(_randomChaosPrediction()),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _chaosMeter =
                  '${(60 + _random.nextInt(41)).toString()}%'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('👹', style: TextStyle(fontSize: 24)),
            title: const Text('What kind of weather gremlin are you?'),
            subtitle: Text(_gremlinPersona),
            trailing: IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: () => setState(() => _gremlinPersona = _randomGremlin()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Text('🎮', style: TextStyle(fontSize: 24)),
            title: const Text('Arcade mini-games'),
            subtitle: const Text(
                'Tiny HTML5 distractions. Coming soon with maximum snark.'),
            trailing: FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.memeGenerator,
              ),
              child: const Text('Meme Generator'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SettingsContent(
        initialPersona: _persona,
        onPersonaChanged: (p) => setState(() => _persona = p),
        showAboutTile: true,
      ),
    );
  }

  Widget _buildPersonaSelector() {
    return Wrap(
      spacing: 8,
      children: PersonaType.values.map((persona) {
        final isSelected = persona == _persona;
        return ChoiceChip(
          label: Text(persona.displayName),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _persona = persona;
              if (_weather != null) {
                final roastService = context.read<PersonaRoastService>();
                _currentRoast = roastService.getRoast(
                  persona: persona,
                  weather: _weather!,
                );
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildHourlyForecast() {
    final hourly = _weather?.hourly ?? [];
    if (hourly.isEmpty) {
      return const Text('Hourly forecast coming soon.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hourly',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: min(hourly.length, 8),
            itemBuilder: (context, index) {
              final hour = hourly[index];
              final time = TimeOfDay.fromDateTime(hour.time).format(context);
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${hour.temperatureF.toStringAsFixed(0)}°F'),
                    Text(hour.condition),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecast() {
    final daily = _weather?.daily ?? [];
    if (daily.isEmpty) {
      return const Text('Daily forecast coming soon.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...daily.take(5).map(
          (day) {
            return Card(
              child: ListTile(
                leading: const Text('☁️', style: TextStyle(fontSize: 18)),
                title: Text('${day.date.month}/${day.date.day} · ${day.condition}'),
                subtitle: Text(
                  'High ${day.maxTempF.toStringAsFixed(0)}° • Low ${day.minTempF.toStringAsFixed(0)}°',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnnoyanceMeter(double score) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'How Annoying Today Feels',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('(${(score * 100).round()}%)'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: score),
            const SizedBox(height: 8),
            Text(_annoyanceLabel(score)),
          ],
        ),
      ),
    );
  }
}
