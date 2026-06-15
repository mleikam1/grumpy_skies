import 'package:flutter/material.dart';

import '../design/dm_theme.dart';
import 'daymaker_router.dart';

class DaymakerApp extends StatelessWidget {
  const DaymakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DayMaker',
      theme: DMTheme.light,
      routerConfig: daymakerRouter,
    );
  }
}
