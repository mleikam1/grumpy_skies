// Run explicitly with -t lib/main_preview.dart. Never used by production main.
import 'package:flutter/widgets.dart';
import 'models/app_appearance.dart';
import 'preview/approved_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const route =
      String.fromEnvironment('PREVIEW_ROUTE', defaultValue: '/forecast');
  const dark = bool.fromEnvironment('PREVIEW_DARK');
  final session = ApprovedPreviewSession(
    initialLocation: route,
    appearance: dark ? AppAppearance.dark : AppAppearance.light,
  );
  await session.initialize();
  runApp(session.build());
}
