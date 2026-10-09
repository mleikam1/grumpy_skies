import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import 'package:provider/provider.dart';
import '../../design/dm_theme.dart';
import '../../shared/widgets/dm_approved_components.dart';
import 'widgets/approved_fun_cards.dart';
import 'meme/meme_catalog.dart';
import 'meme/models/meme_document.dart';
import 'meme/storage/meme_store.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../monetization/ad_placement.dart';
import '../../monetization/widgets/ad_section.dart';
import 'widgets/fun_feature_tile.dart';
import 'widgets/fun_wheel_visual.dart';

class FunZoneScreen extends StatefulWidget {
  const FunZoneScreen({super.key, this.store});
  final MemeStore? store;

  @override
  State<FunZoneScreen> createState() => _FunZoneScreenState();
}

class _FunZoneScreenState extends State<FunZoneScreen> {
  static const _fortunes = [
    'Your umbrella has main-character energy today.',
    'Clouds are planning a dramatic entrance after lunch.',
    'A suspiciously cheerful breeze is headed your way.',
    'Your sunglasses will feel smug by 3 PM.',
  ];

  static const _predictions = [
    '74% chance of accidental sparkle.',
    '58% chance of snack-weather alignment.',
    '91% chance of sidewalk weather commentary.',
    '66% chance the forecast changes its mind.',
  ];

  static const _menaces = [
    'Sunbeam Instigator',
    'Drizzle Diplomat',
    'Wind Gust Showoff',
    'Humidity Headliner',
  ];

  int _tab = 0;
  late final Future<MemeCatalog> _catalog = MemeCatalog.load();
  MemeStore? _store;
  Future<List<MemeDocument>>? _documents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??=
        widget.store ?? context.read<MemeStore?>() ?? MemeStore.platform();
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 2) _documents = _store!.listDocuments();
    });
  }

  Future<void> _openTemplate(String id) async {
    await context.push('${AppRoutes.memeGenerator}?template=$id');
    if (mounted && _tab == 2) {
      setState(() => _documents = _store!.listDocuments());
    }
  }

  var _fortuneIndex = -1;
  var _predictionIndex = -1;
  var _menaceIndex = -1;
  var _hasCrackedFortune = false;
  var _hasSpun = false;
  var _hasFoundMenace = false;

  void _crackFortune() {
    setState(() {
      _hasCrackedFortune = true;
      _fortuneIndex = (_fortuneIndex + 1) % _fortunes.length;
    });
    // TODO(haptics): Add a gentle success tick when the cookie opens.
    _showSnackBar('Fortune cookie cracked. Weather reveal ready.');
  }

  void _spinPrediction() {
    setState(() {
      _hasSpun = true;
      _predictionIndex = (_predictionIndex + 1) % _predictions.length;
    });
  }

  void _findMenace() {
    setState(() {
      _hasFoundMenace = true;
      _menaceIndex = (_menaceIndex + 1) % _menaces.length;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _openMemeGenerator() {
    context.push(AppRoutes.memeGenerator);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.dmColors.appBackground,
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          return ListView(
              key: const PageStorageKey('fun-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const DmPageHeader(title: 'Fun Zone'),
                              const SizedBox(height: 16),
                              Text('WEATHER + MEMES = BETTER DAYS',
                                  style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w800,
                                      color: context.dmColors.insightIcon)),
                              const SizedBox(height: 7),
                              const Text(
                                  'Turn your forecast\ninto a punchline.',
                                  style: TextStyle(
                                      fontSize: 32,
                                      height: 1.05,
                                      letterSpacing: -1,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 16),
                              _tabs(),
                              const SizedBox(height: 12),
                              if (_tab == 0) ...[
                                ApprovedFunPromo(
                                    onCreate: () =>
                                        _openTemplate('approved_current_mood')),
                                DmApprovedSectionHeader(
                                    title: 'Quick templates',
                                    onAction: () => _selectTab(1)),
                                _quickTemplates(),
                                const SizedBox(height: 4),
                                const SizedBox(
                                    height: 36,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Featured meme',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800)))),
                                ApprovedFeaturedMeme(
                                    onTap: () =>
                                        _openTemplate('approved_beach_sun')),
                                const SizedBox(height: 24),
                                const DmApprovedSectionHeader(
                                    title: 'More ways to make your day'),
                                _fortuneTile(),
                                const SizedBox(height: 16),
                                if (_hasCrackedFortune)
                                  const AdSection(
                                      placement: AdPlacement.funHubMrec),
                                if (wide)
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _predictorTile()),
                                        const SizedBox(width: 16),
                                        Expanded(child: _menaceTile())
                                      ])
                                else ...[
                                  _predictorTile(),
                                  const SizedBox(height: 16),
                                  _menaceTile()
                                ],
                              ] else if (_tab == 1)
                                _templateLibrary()
                              else
                                _savedMemes(),
                            ]))),
              ]);
        })),
      );

  Widget _tabs() => Container(
      decoration: BoxDecoration(
          color: context.dmColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(26)),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
              child: Semantics(
                  selected: _tab == i,
                  child: TextButton(
                      onPressed: () => _selectTab(i),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          backgroundColor: _tab == i
                              ? context.dmColors.surface
                              : Colors.transparent,
                          foregroundColor: _tab == i
                              ? context.dmColors.textPrimary
                              : context.dmColors.textSecondary,
                          textStyle: const TextStyle(
                              fontFamily: 'DaymakerSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      child: Text(['Make a meme', 'Templates', 'My memes'][i],
                          textAlign: TextAlign.center)))),
      ]));

  Widget _quickTemplates() {
    final tiles = [
      ApprovedTemplateTile(
          title: 'Current mood',
          caption: 'Same forecast. Different attitude.',
          asset: 'assets/approved_v1/weather/sun_sunglasses.png',
          color: context.dmColors.templateSun,
          onTap: () => _openTemplate('approved_current_mood')),
      ApprovedTemplateTile(
          title: 'Monday energy',
          caption: 'Cloudy with a chance of caffeine.',
          asset: 'assets/approved_v1/weather/coffee_cloud.png',
          color: context.dmColors.templateCoffee,
          onTap: () => _openTemplate('approved_monday_energy')),
      ApprovedTemplateTile(
          title: 'This weather…',
          caption: 'Looks serious. Just like my snacks.',
          asset: 'assets/approved_v1/weather/storm_cloud.png',
          color: context.dmColors.templateStorm,
          onTap: () => _openTemplate('approved_this_weather')),
    ];
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final tile in tiles)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: tile)
      ]);
    }
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: tiles[i])
      ]
    ]));
  }

  Widget _templateLibrary() => FutureBuilder<MemeCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(children: [
            const Text('Templates could not load.'),
            TextButton(
                onPressed: _openMemeGenerator,
                child: const Text('Open Meme Studio'))
          ]);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(children: [
          for (final template in snapshot.data!.templates)
            Card(
                child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: SizedBox(
                        width: 64,
                        height: 64,
                        child: Image.asset(template.thumbnailPath,
                            fit: BoxFit.contain)),
                    title: Text(template.name),
                    subtitle: Text(template.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openTemplate(template.id)))
        ]);
      });

  Widget _savedMemes() => FutureBuilder<List<MemeDocument>>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
              'Saved memes could not be read. Open Meme Studio to retry.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                const Icon(Icons.photo_library_outlined, size: 42),
                const SizedBox(height: 12),
                const Text('Your next great meme starts here.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _openMemeGenerator,
                    child: const Text('Create a meme'))
              ]));
        }
        return Column(children: [
          for (final document in snapshot.data!)
            Card(
                child: ListTile(
                    title: Text(document.name),
                    subtitle: const Text('Saved on this device'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => context.push(
                        '${AppRoutes.memeGenerator}?document=${Uri.encodeComponent(document.id)}')))
        ]);
      });

  Widget _fortuneTile({
    bool featured = false,
    double? minHeight,
  }) {
    return FunFeatureTile(
      icon: Icons.auto_awesome_rounded,
      title: 'Weather Fortune Cookie',
      subtitle: 'Crack a cookie. Get a playful fortune, just for fun.',
      actionLabel: 'Crack One',
      actionSemanticLabel: 'Crack fortune cookie',
      onAction: _crackFortune,
      accentColor: DMColors.sunriseYellow,
      featured: featured,
      minHeight: minHeight,
      gradient: context.dmColors.heroGradient,
      body: _RevealPill(
        label: _hasCrackedFortune ? 'Reveal' : 'Ready',
        value: _hasCrackedFortune
            ? _fortunes[_fortuneIndex]
            : 'Tap Crack One for today\'s hint.',
        color: DMColors.sunriseYellow,
      ),
    );
  }

  Widget _predictorTile({
    bool compactWheel = false,
    double? minHeight,
  }) {
    return FunFeatureTile(
      icon: Icons.cyclone_outlined,
      title: 'Crazy Day Predictor',
      subtitle: 'Imaginary odds, just for fun.',
      actionLabel: 'Spin Now',
      actionSemanticLabel: 'Spin crazy day predictor',
      onAction: _spinPrediction,
      accentColor: DMColors.playfulPink,
      minHeight: minHeight,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FunWheelVisual(size: compactWheel ? 112 : 144),
          const SizedBox(height: DMSpacing.md),
          _RevealPill(
            label: _hasSpun ? 'Prediction' : 'Forecast mood',
            value: _hasSpun
                ? _predictions[_predictionIndex]
                : 'Currently spinning up nonsense.',
            color: DMColors.playfulPink,
          ),
        ],
      ),
    );
  }

  Widget _menaceTile({double? minHeight}) {
    return FunFeatureTile(
      icon: Icons.person_search_outlined,
      title: 'Weather Menace',
      subtitle: 'What kind of weather menace are you?',
      actionLabel: 'Find Out',
      actionSemanticLabel: 'Find your weather menace type',
      onAction: _findMenace,
      accentColor: DMColors.lavenderGlass,
      minHeight: minHeight,
      body: _RevealPill(
        label: _hasFoundMenace ? 'Type' : 'Mystery',
        value: _hasFoundMenace ? _menaces[_menaceIndex] : 'Identity pending.',
        color: DMColors.lavenderGlass,
      ),
    );
  }
}

class _RevealPill extends StatelessWidget {
  const _RevealPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(color, 0.12),
        borderRadius: DMRadius.large,
        border: Border.all(color: DMColors.opacity(color, 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelSmall.copyWith(color: color),
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
