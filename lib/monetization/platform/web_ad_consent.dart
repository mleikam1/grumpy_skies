import 'package:flutter/foundation.dart';

/// A verified, site-specific certified CMP supplies this boundary. Neither UMP
/// mobile consent nor choosing nonpersonalized ads authorizes web requests.
/// Production must connect required Google consent signals before allowing ads.
abstract class WebAdConsent extends ChangeNotifier {
  bool get cmpConfigured;
  bool get resolved;
  bool get canRequestAds;
  Future<void> initialize();
  Future<void> showPrivacyOptions();
}

/// Honest launch default: no approved web CMP/account is configured. This never
/// injects tags, manufactures consent, or stores a user's supposed preference.
class UnconfiguredWebAdConsent extends WebAdConsent {
  @override
  bool get cmpConfigured => false;
  @override
  bool get resolved => false;
  @override
  bool get canRequestAds => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> showPrivacyOptions() async {}
}
