import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'monetization_controller.dart';

/// Modal accounting only. Navigation observation can never present an ad.
class AdModalObserver extends NavigatorObserver {
  final Set<Route<dynamic>> _modals = {};
  void _change(Route<dynamic> route, bool added) {
    if (route is! PopupRoute) return;
    final changed = added ? _modals.add(route) : _modals.remove(route);
    if (!changed) return;
    final context = navigator?.context;
    final controller = context?.read<MonetizationController?>();
    if (added) {
      controller?.beginOperation(deferNotification: true);
    } else {
      // didPop precedes reverse animation. Keep safety gated until the overlay
      // has actually been removed, including an asynchronously saved reservation.
      route.completed.whenComplete(
          () => controller?.endOperation(deferNotification: true));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, true);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, false);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, false);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _change(oldRoute, false);
    if (newRoute != null) _change(newRoute, true);
  }
}
