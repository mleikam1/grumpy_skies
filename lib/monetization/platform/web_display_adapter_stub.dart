import '../ad_placement.dart';
import '../ad_reporting.dart';
import 'ad_platform.dart';
import 'web_ad_consent.dart';

class WebDisplayAdapter implements DisplayAdAdapter {
  const WebDisplayAdapter({
    required this.consent,
    this.placementAllowed = _denyPlacement,
  });
  final WebAdConsent consent;
  final bool Function(AdPlacement) placementAllowed;
  @override
  Future<DisplayAdHandle?> load({
    required String unitId,
    required DisplaySize size,
    required AdPlacement placement,
    required AdReporter reporter,
  }) async =>
      null;
}

bool _denyPlacement(AdPlacement _) => false;
