import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/dm_theme.dart';
import '../models/app_appearance.dart';
import '../services/settings_controller.dart';
import 'daymaker_router.dart';

class DaymakerApp extends StatelessWidget {
  const DaymakerApp({super.key, this.routerConfig});

  final RouterConfig<Object>? routerConfig;

  @override
  Widget build(BuildContext context) {
    final appearance = context.select<SettingsController?, AppAppearance>(
      (settings) => settings?.appearance ?? AppAppearance.light,
    );
    return MaterialApp.router(
      title: 'DayMaker',
      theme: DMTheme.lightTheme,
      darkTheme: DMTheme.darkTheme,
      themeMode: appearance.themeMode,
      themeAnimationDuration: (MediaQuery.maybeDisableAnimationsOf(context) ??
              WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
                  .disableAnimations)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      routerConfig: routerConfig ?? daymakerRouter,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: DMTheme.systemOverlayFor(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
