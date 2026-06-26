import 'weather_roast_models.dart';

class RoastPackValidationResult {
  const RoastPackValidationResult({
    this.errors = const [],
    this.warnings = const [],
  });

  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;
}

class RoastPackValidator {
  static const expectedSchemaVersion = 1;

  const RoastPackValidator();

  RoastPackValidationResult validatePack(RoastPack pack) {
    final errors = <String>[];
    final warnings = <String>[];
    final seenIds = <String>{};
    final seenText = <String>{};
    final fallbackPersonas = <String>{};

    if (pack.schemaVersion != expectedSchemaVersion) {
      errors.add(
        'Unsupported schema_version ${pack.schemaVersion}; expected '
        '$expectedSchemaVersion.',
      );
    }
    if (pack.packVersion.trim().isEmpty) {
      errors.add('pack_version is required.');
    }
    if (pack.roasts.isEmpty) {
      errors.add('Pack must contain at least one roast.');
    }

    for (final persona in pack.personas) {
      final normalized = normalizeRoastPersonaId(persona);
      if (!supportedWeatherRoastPersonas.contains(normalized)) {
        errors.add('Unknown persona in personas list: $persona.');
      }
    }

    for (final roast in pack.roasts) {
      errors.addAll(validateRoast(roast));

      if (!seenIds.add(roast.id)) {
        errors.add('Duplicate roast id: ${roast.id}.');
      }

      final normalizedText = roast.text.trim().toLowerCase();
      if (normalizedText.isNotEmpty && !seenText.add(normalizedText)) {
        warnings.add('Duplicate text: ${roast.id}.');
      }

      if (roast.text.length > 180) {
        warnings.add('Very long copy (${roast.text.length} chars): '
            '${roast.id}.');
      }

      if (roast.isFallback) {
        fallbackPersonas.add(roast.persona);
      }
    }

    for (final persona in supportedWeatherRoastPersonas) {
      if (!fallbackPersonas.contains(persona)) {
        warnings.add('Missing fallback for persona: $persona.');
      }
    }

    return RoastPackValidationResult(
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
    );
  }

  List<String> validateRoast(RoastLine roast) {
    final errors = <String>[];

    if (roast.id.trim().isEmpty) {
      errors.add('Roast id is required.');
    }
    if (!supportedWeatherRoastPersonas.contains(roast.persona)) {
      errors.add('Unknown persona for ${roast.id}: ${roast.persona}.');
    }
    if (roast.text.trim().isEmpty) {
      errors.add('Roast text is required for ${roast.id}.');
    }
    if (roast.weight <= 0) {
      errors.add('Weight must be greater than zero for ${roast.id}.');
    }
    if (roast.tags.isEmpty) {
      errors.add('At least one weather tag is required for ${roast.id}.');
    }
    if (roast.dayparts.isEmpty) {
      errors.add('At least one daypart is required for ${roast.id}.');
    }
    if (roast.tempMinF != null &&
        roast.tempMaxF != null &&
        roast.tempMinF! > roast.tempMaxF!) {
      errors.add('temp_min_f must be <= temp_max_f for ${roast.id}.');
    }
    errors.addAll(_placeholderErrors(roast.text, roast.id));
    final fallbackText = roast.fallbackText;
    if (fallbackText != null) {
      errors.addAll(_placeholderErrors(fallbackText, roast.id));
    }

    return errors;
  }

  List<String> _placeholderErrors(String text, String id) {
    return RegExp(r'\{([a-zA-Z0-9_]+)\}')
        .allMatches(text)
        .map((match) => match.group(1)!)
        .where(
            (placeholder) => !supportedRoastPlaceholders.contains(placeholder))
        .map((placeholder) => 'Invalid placeholder {$placeholder} in $id.')
        .toList(growable: false);
  }
}
