import 'package:flutter/material.dart';
import 'meme/meme_studio.dart';
import 'meme/meme_weather.dart';
import 'meme/platform/meme_export_service.dart';
import 'meme/storage/meme_store.dart';

/// Both /fun/meme and /meme-generator open the same local studio.
class MemeGeneratorScreen extends StatelessWidget {
  const MemeGeneratorScreen(
      {super.key,
      this.initialRoast,
      this.initialTemplateId,
      this.initialDocumentId,
      this.store,
      this.exports,
      this.recoverLostImages = true});
  final DisplayedRoastSnapshot? initialRoast;
  final String? initialTemplateId;
  final String? initialDocumentId;
  final MemeStore? store;
  final MemeExportService? exports;
  final bool recoverLostImages;
  @override
  Widget build(BuildContext context) => MemeStudio(
      initialRoast: initialRoast,
      initialTemplateId: initialTemplateId,
      initialDocumentId: initialDocumentId,
      store: store,
      exports: exports,
      recoverLostImages: recoverLostImages);
}
