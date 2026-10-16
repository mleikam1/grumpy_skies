import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../plancast_controller.dart';

/// Start after the first frame so private calendar work never holds up weather.
class PlanCastLifecycle extends StatefulWidget {
  const PlanCastLifecycle(
      {super.key,
      required this.controller,
      required this.router,
      required this.child});
  final PlanCastController controller;
  final GoRouter router;
  final Widget child;
  @override
  State<PlanCastLifecycle> createState() => _PlanCastLifecycleState();
}

class _PlanCastLifecycleState extends State<PlanCastLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _subscription;
  bool _handlingRoute = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.controller.platform.changes.listen((change) {
      if (change == 'notificationOpened') unawaited(_openNotification());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.controller.initialize();
      if (mounted) await _openNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    } else {
      unawaited(widget.controller.stopSpeaking());
    }
  }

  Future<void> _resume() async {
    await widget.controller.initialize();
    await widget.controller.onResume();
    if (mounted) await _openNotification();
  }

  Future<void> _openNotification() async {
    if (_handlingRoute) return;
    _handlingRoute = true;
    try {
      final value = await widget.controller.consumeNotificationRoute();
      if (value == null || !mounted) return;
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.hasScheme ||
          uri.hasAuthority ||
          uri.path != '/plancast') {
        return;
      }
      final event = uri.queryParameters['event'];
      final day = uri.queryParameters['day'];
      if (event != null && !RegExp(r'^[a-f0-9]{24}$').hasMatch(event)) return;
      if (day != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return;
      widget.router.push(Uri(path: '/plancast', queryParameters: {
        if (event != null) 'event': event,
        if (day != null) 'day': day
      }).toString());
    } catch (_) {
      // A failed optional deep link cannot interrupt the normal forecast.
    } finally {
      _handlingRoute = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
