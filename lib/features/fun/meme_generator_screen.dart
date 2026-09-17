import 'package:flutter/material.dart';
import 'meme/meme_studio.dart';
import 'meme/meme_weather.dart';
import 'meme/platform/meme_export_service.dart';
import 'meme/storage/meme_store.dart';

/// Both /fun/meme and /meme-generator open the same local studio.
class MemeGeneratorScreen extends StatelessWidget {
  const MemeGeneratorScreen(
      {super.key, this.initialRoast, this.store, this.exports});
  final DisplayedRoastSnapshot? initialRoast;
  final MemeStore? store;
  final MemeExportService? exports;
  @override
  Widget build(BuildContext context) =>
      MemeStudio(initialRoast: initialRoast, store: store, exports: exports);
}
