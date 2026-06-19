import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../models/weather_models.dart';
import '../../services/weather_location_controller.dart';
import 'dm_buttons.dart';
import 'dm_glass_card.dart';

class WeatherLocationSelector extends StatefulWidget {
  const WeatherLocationSelector({
    super.key,
    required this.controller,
    this.title = 'Choose your weather spot',
    this.onLocationSelected,
  });

  final WeatherLocationController controller;
  final String title;
  final ValueChanged<LocationCandidate>? onLocationSelected;

  @override
  State<WeatherLocationSelector> createState() =>
      _WeatherLocationSelectorState();
}

class _WeatherLocationSelectorState extends State<WeatherLocationSelector> {
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController(text: 'US');

  Timer? _debounce;
  List<LocationCandidate> _cityResults = const [];
  String? _cityError;
  String? _zipError;
  var _cityLoading = false;
  var _zipLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    await widget.controller.useCurrentLocation();
    final selected = widget.controller.selectedLocation;
    if (selected != null) {
      widget.onLocationSelected?.call(selected);
    }
  }

  void _onCityChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchCity(value);
    });
  }

  Future<void> _searchCity(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _cityResults = const [];
        _cityError = null;
        _cityLoading = false;
      });
      return;
    }

    setState(() {
      _cityLoading = true;
      _cityError = null;
    });

    try {
      final results = await widget.controller.searchCity(query);
      if (!mounted) return;
      setState(() {
        _cityResults = results;
        _cityError = results.isEmpty
            ? 'No matching cities. Try a broader search.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cityResults = const [];
        _cityError = 'City search is unavailable. Try again soon.';
      });
    } finally {
      if (mounted) {
        setState(() => _cityLoading = false);
      }
    }
  }

  Future<void> _searchZip() async {
    final zip = _zipController.text.trim();
    final country = _countryController.text.trim().toUpperCase();
    if (zip.length < 2) {
      setState(() => _zipError = 'Enter a ZIP or postal code.');
      return;
    }

    setState(() {
      _zipLoading = true;
      _zipError = null;
    });

    try {
      final location = await widget.controller.searchZip(
        zip,
        country: country.isEmpty ? 'US' : country,
      );
      if (!mounted) return;
      if (location == null) {
        setState(() => _zipError = 'No location found for that postal code.');
        return;
      }
      await _selectLocation(location);
    } catch (_) {
      if (!mounted) return;
      setState(() => _zipError = 'Postal search is unavailable right now.');
    } finally {
      if (mounted) {
        setState(() => _zipLoading = false);
      }
    }
  }

  Future<void> _selectLocation(LocationCandidate location) async {
    await widget.controller.selectLocation(location);
    widget.onLocationSelected?.call(location);
  }

  @override
  Widget build(BuildContext context) {
    final statusMessage = widget.controller.message;

    return DmGlassCard(
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: DMColors.sunriseYellow,
              ),
              const SizedBox(width: DMSpacing.sm),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.sm),
          DmPillButton(
            label: 'Use my current location',
            semanticLabel: 'Use my current location',
            leading: const Icon(Icons.my_location),
            loading:
                widget.controller.status == LocationSelectionStatus.loading,
            onPressed: _useCurrentLocation,
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: DMSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                statusMessage,
                style: DMTypography.bodySmall.copyWith(
                  color: _statusColor(widget.controller.status),
                ),
              ),
            ),
          ],
          const SizedBox(height: DMSpacing.lg),
          _SearchField(
            controller: _cityController,
            label: 'City, state, or country',
            hint: 'Austin, TX',
            icon: Icons.search,
            loading: _cityLoading,
            onChanged: _onCityChanged,
            onSubmitted: _searchCity,
          ),
          if (_cityError != null) _InlineMessage(message: _cityError!),
          if (_cityResults.isNotEmpty) ...[
            const SizedBox(height: DMSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: DMColors.opacity(DMColors.cloudWhite, 0.07),
                borderRadius: DMRadius.large,
                border: Border.all(color: DMColors.outlineVariant),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < _cityResults.length; index++)
                    _LocationResultTile(
                      location: _cityResults[index],
                      showDivider: index < _cityResults.length - 1,
                      onTap: () => _selectLocation(_cityResults[index]),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DMSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final zipField = _SearchField(
                controller: _zipController,
                label: 'ZIP or postal code',
                hint: '60601',
                icon: Icons.local_post_office_outlined,
                loading: _zipLoading,
                onSubmitted: (_) => _searchZip(),
              );
              final countryField = SizedBox(
                width: compact ? double.infinity : 96,
                child: _SearchField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'US',
                  icon: Icons.flag_outlined,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _searchZip(),
                ),
              );
              final button = DmPillButton(
                label: 'Find ZIP',
                semanticLabel: 'Find ZIP or postal code location',
                leading: const Icon(Icons.travel_explore),
                loading: _zipLoading,
                onPressed: _searchZip,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    zipField,
                    const SizedBox(height: DMSpacing.sm),
                    countryField,
                    const SizedBox(height: DMSpacing.sm),
                    button,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: zipField),
                  const SizedBox(width: DMSpacing.sm),
                  countryField,
                  const SizedBox(width: DMSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: button,
                  ),
                ],
              );
            },
          ),
          if (_zipError != null) _InlineMessage(message: _zipError!),
        ],
      ),
    );
  }

  static Color _statusColor(LocationSelectionStatus status) {
    return switch (status) {
      LocationSelectionStatus.success => DMColors.mintSoft,
      LocationSelectionStatus.denied ||
      LocationSelectionStatus.unavailable ||
      LocationSelectionStatus.error =>
        DMColors.sunriseYellow,
      _ => DMColors.textMuted,
    };
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.loading = false,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool loading;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      textCapitalization: textCapitalization,
      style: DMTypography.body.copyWith(color: DMColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DMSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: DMTypography.bodySmall.copyWith(
            color: DMColors.sunriseYellow,
          ),
        ),
      ),
    );
  }
}

class _LocationResultTile extends StatelessWidget {
  const _LocationResultTile({
    required this.location,
    required this.showDivider,
    required this.onTap,
  });

  final LocationCandidate location;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: DMColors.outlineVariant),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DMSpacing.sm,
              vertical: DMSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: DMColors.skyBlueSoft,
                ),
                const SizedBox(width: DMSpacing.sm),
                Expanded(
                  child: Text(
                    location.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.labelLarge,
                  ),
                ),
                const SizedBox(width: DMSpacing.sm),
                const Icon(
                  Icons.chevron_right,
                  color: DMColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
