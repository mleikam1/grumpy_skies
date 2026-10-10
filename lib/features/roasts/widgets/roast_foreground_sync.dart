import 'dart:async';
import 'package:flutter/widgets.dart';
import '../content/roast_pack_repository.dart';
import '../controllers/local_roast_controller.dart';

/// The only app-level entry point for optional content network work. Selection,
/// persona switching and rebuilding this widget never call the updater.
class RoastForegroundSync extends StatefulWidget {
  const RoastForegroundSync(
      {super.key,
      required this.controller,
      required this.child,
      this.policy = RoastUpdatePolicy.disabled});
  final LocalRoastController controller;
  final Widget child;
  final RoastUpdatePolicy policy;
  @override
  State<RoastForegroundSync> createState() => _RoastForegroundSyncState();
}

class _RoastForegroundSyncState extends State<RoastForegroundSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() => unawaited(
      widget.controller.syncUpdatesInForeground(policy: widget.policy));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
