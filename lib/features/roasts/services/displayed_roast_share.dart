import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_routes.dart';
import '../../../monetization/monetization_controller.dart';
import '../../../services/weather_location_controller.dart';
import '../../fun/meme/meme_weather.dart';

/// All destinations receive the same immutable text/weather displayed by the
/// caller. This function never requests weather, generates text or changes it.
Future<void> showDisplayedRoastShareSheet(
  BuildContext context,
  DisplayedRoastSnapshot source,
) async {
  bool alertActive() =>
      context.read<WeatherLocationController?>()?.safetyStatus ==
      WeatherSafetyStatus.activeAlert;
  if (alertActive()) return;
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Share this exact roast',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(source.text),
        const SizedBox(height: 12),
        ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Share'),
            onTap: () => Navigator.pop(context, 'share')),
        ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy text'),
            onTap: () => Navigator.pop(context, 'copy')),
        ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Make a meme'),
            onTap: () => Navigator.pop(context, 'meme')),
      ]),
    ),
  );
  if (!context.mounted || action == null || alertActive()) return;
  try {
    if (action == 'meme') {
      context.push(AppRoutes.memeGenerator, extra: source);
      return;
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: source.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Roast copied.')));
      }
      return;
    }
    // Platform share UI is not a Navigator modal. Keep the existing ad operation
    // guard active until it completes, including cancel/error outcomes.
    final ads = context.read<MonetizationController?>();
    final box = context.findRenderObject() as RenderBox?;
    ads?.beginOperation();
    try {
      await SharePlus.instance.share(ShareParams(
          text: source.text,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } finally {
      ads?.endOperation();
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sharing is unavailable. Try Copy text.')));
    }
  }
}
