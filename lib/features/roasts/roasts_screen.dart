import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/daymaker_sample_data.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../models/daymaker_models.dart';
import '../../repositories/roast_repository.dart';
import '../../shared/widgets/daymaker_components.dart';
import 'widgets/daymaker_persona_carousel.dart';
import 'widgets/featured_roast_card.dart';
import 'widgets/roast_cooldown_card.dart';
import 'widgets/roast_history_list.dart';
import 'widgets/roasts_brand_header.dart';

class RoastsScreen extends StatefulWidget {
  const RoastsScreen({
    super.key,
    this.roastRepository,
  });

  final RoastRepository? roastRepository;

  @override
  State<RoastsScreen> createState() => _RoastsScreenState();
}

class _RoastsScreenState extends State<RoastsScreen> {
  RoastRepository? _repository;
  var _loadedRepository = false;
  var _loading = true;
  Object? _error;

  List<Persona> _personas = const [];
  Map<String, Roast> _dailyRoasts = const {};
  List<Roast> _history = const [];
  String? _selectedPersonaId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedRepository) return;

    _repository = widget.roastRepository ?? context.read<RoastRepository>();
    _loadedRepository = true;
    _loadRoasts();
  }

  @override
  void didUpdateWidget(covariant RoastsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roastRepository != widget.roastRepository &&
        widget.roastRepository != null) {
      _repository = widget.roastRepository;
      _loadRoasts();
    }
  }

  Future<void> _loadRoasts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = _repository!;
      final personas = await repository.getPersonas();
      final dailyRoasts = await Future.wait(
        personas.map(
          (persona) => repository.getDailyRoast(
            personaId: persona.id,
            weatherSnapshotId: DayMakerSampleData.weatherSnapshot.id,
          ),
        ),
      );
      final history = await repository.getRoastHistory();

      if (!mounted) return;

      final currentSelection = _selectedPersonaId;
      final hasCurrentSelection =
          personas.any((persona) => persona.id == currentSelection);
      final selectedPersonaId = hasCurrentSelection
          ? currentSelection
          : personas.isEmpty
              ? null
              : personas.first.id;

      setState(() {
        _personas = personas;
        _dailyRoasts = {
          for (var index = 0; index < personas.length; index++)
            personas[index].id: dailyRoasts[index],
        };
        _history = List.unmodifiable(history);
        _selectedPersonaId = selectedPersonaId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectPersona(Persona persona) {
    setState(() => _selectedPersonaId = persona.id);
  }

  void _showShareSnackBar(Roast _) {
    // TODO(haptics): Add success feedback when native sharing is wired.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Share action coming soon.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.appBackground,
        color: DMColors.deepNavy,
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _personas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: DMColors.sunriseYellow),
      );
    }

    if (_error != null && _personas.isEmpty) {
      return _RoastsStateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Roasts unavailable',
        message: 'Try again in a moment.',
        actionLabel: 'Retry',
        onAction: _loadRoasts,
      );
    }

    if (_personas.isEmpty || _selectedPersona == null) {
      return _RoastsStateMessage(
        icon: Icons.person_off_outlined,
        title: 'No personas yet',
        message: 'DayMaker is still warming up the roast bench.',
        actionLabel: 'Retry',
        onAction: _loadRoasts,
      );
    }

    final selectedPersona = _selectedPersona!;
    final featuredRoast = _featuredRoastFor(selectedPersona);
    final history = _historyFor(selectedPersona);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final breakpoint = DMBreakpoints.fromWidth(width);
        final maxWidth = switch (breakpoint) {
          DMBreakpoint.compact => double.infinity,
          DMBreakpoint.medium => 760.0,
          DMBreakpoint.expanded => 980.0,
        };
        final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;

        return RefreshIndicator(
          color: DMColors.deepNavy,
          backgroundColor: DMColors.sunriseYellow,
          onRefresh: _loadRoasts,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: DMSpacing.pagePaddingForWidth(width).copyWith(
              bottom: DMSpacing.x2,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RoastsBrandHeader(),
                      SizedBox(height: gap),
                      FeaturedRoastCard(
                        persona: selectedPersona,
                        roast: featuredRoast,
                        weather: DayMakerSampleData.weatherSnapshot,
                        onShare: () => _showShareSnackBar(featuredRoast),
                      ),
                      SizedBox(height: gap),
                      const DmSectionHeader(
                        title: 'Persona carousel',
                        subtitle: 'Choose the voice of today\'s forecast.',
                      ),
                      const SizedBox(height: DMSpacing.sm),
                      DaymakerPersonaCarousel(
                        personas: _personas,
                        selectedPersonaId: selectedPersona.id,
                        onPersonaSelected: _selectPersona,
                      ),
                      SizedBox(height: gap),
                      RoastHistoryList(
                        roasts: history,
                        personas: _personas,
                        onShareRoast: _showShareSnackBar,
                      ),
                      SizedBox(height: gap),
                      const RoastCooldownCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Persona? get _selectedPersona {
    final selectedId = _selectedPersonaId;
    if (selectedId == null) return null;

    for (final persona in _personas) {
      if (persona.id == selectedId) {
        return persona;
      }
    }

    return _personas.isEmpty ? null : _personas.first;
  }

  Roast _featuredRoastFor(Persona persona) {
    return _dailyRoasts[persona.id] ??
        _history.firstWhere(
          (roast) => roast.personaId == persona.id,
          orElse: () => DayMakerSampleData.roast,
        );
  }

  List<Roast> _historyFor(Persona persona) {
    final personaHistory = _history
        .where((roast) => roast.personaId == persona.id)
        .toList(growable: false);

    if (personaHistory.isNotEmpty) {
      return personaHistory;
    }

    return _history.take(3).toList(growable: false);
  }
}

class _RoastsStateMessage extends StatelessWidget {
  const _RoastsStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DMSpacing.screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DmGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: DMColors.sunriseYellow, size: 40),
                const SizedBox(height: DMSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DMTypography.headingSmall,
                ),
                const SizedBox(height: DMSpacing.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: DMTypography.body,
                ),
                const SizedBox(height: DMSpacing.lg),
                DmPillButton(
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
