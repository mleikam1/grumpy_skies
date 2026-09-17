import 'package:flutter/widgets.dart';
import '../ad_placement.dart';
import '../ad_reporting.dart';

abstract interface class DisplayAdHandle {
  Widget get widget;
  void dispose();
}

abstract interface class DisplayAdAdapter {
  Future<DisplayAdHandle?> load(
      {required String unitId,
      required DisplaySize size,
      required AdPlacement placement,
      required AdReporter reporter});
}

/// Web inventory can only request after its actual platform-view DOM is mounted.
/// It returns a deferred handle, then reports no-fill/script/consent failures.
abstract interface class DeferredDisplayAdHandle implements DisplayAdHandle {
  Listenable get stateChanges;
  bool get failed;
}
