import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../ad_placement.dart';
import '../ad_reporting.dart';
import 'ad_platform.dart';
import 'web_ad_consent.dart';

@JS('daymakerAds.mount')
external void _mount(web.HTMLElement element, JSString id, JSString unit,
    JSNumber width, JSNumber height, JSFunction allowed, JSFunction event);
@JS('daymakerAds.destroy')
external void _destroy(JSString id);

/// Separate GAM/GPT web inventory; this rejects all AdMob-style unit IDs.
/// The local bridge never contacts Google until a connected, visible DOM slot
/// has verified CMP permission. No web interstitial/revenue estimation exists.
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
  }) async {
    if (!placementAllowed(placement) ||
        !consent.cmpConfigured ||
        !consent.resolved ||
        !consent.canRequestAds ||
        !placement.isDisplay ||
        !RegExp(r'^/\d+/[A-Za-z0-9_/-]+$').hasMatch(unitId) ||
        !const [
          DisplaySize(320, 50),
          DisplaySize(728, 90),
          DisplaySize(300, 250)
        ].contains(size)) {
      return null;
    }
    return _WebDisplayHandle(
        unitId, size, placement, reporter, consent, placementAllowed);
  }
}

class _WebDisplayHandle extends ChangeNotifier
    implements DeferredDisplayAdHandle {
  _WebDisplayHandle(this.unit, this.size, this.placement, this.reporter,
      this.consent, this.placementAllowed) {
    consent.addListener(_consentChanged);
  }
  static int _sequence = 0;
  final String _id = 'daymaker-gpt-${++_sequence}';
  final String unit;
  final DisplaySize size;
  final AdPlacement placement;
  final AdReporter reporter;
  final WebAdConsent consent;
  final bool Function(AdPlacement) placementAllowed;
  bool _disposed = false, _failed = false, _mounted = false;
  bool _requested = false, _loaded = false, _impression = false;
  late final JSFunction _allowed = (() => (!_disposed &&
          !_failed &&
          placementAllowed(placement) &&
          consent.cmpConfigured &&
          consent.resolved &&
          consent.canRequestAds)
      .toJS).toJS;
  late final JSFunction _event =
      ((JSString event) => _received(event.toDart)).toJS;

  @override
  Listenable get stateChanges => this;
  @override
  bool get failed => _failed;

  void _received(String event) {
    if (_disposed || _failed) return;
    switch (event) {
      case 'request':
        if (!_requested) {
          reporter.report(AdEvent(AdEventKind.request, placement));
        }
        _requested = true;
      case 'loaded':
        if (!_loaded) reporter.report(AdEvent(AdEventKind.loaded, placement));
        _loaded = true;
      case 'viewable':
        if (!_impression) {
          reporter.report(AdEvent(AdEventKind.impression, placement,
              reason: 'gpt_viewable_impression'));
        }
        _impression = true;
      default:
        _failed = true;
        reporter.report(
            AdEvent(AdEventKind.loadFailure, placement, reason: 'web_$event'));
        _destroySafely();
        notifyListeners();
    }
  }

  void _consentChanged() {
    if (!consent.cmpConfigured || !consent.resolved || !consent.canRequestAds) {
      _received('consent_unavailable');
    }
  }

  void _created(Object element) {
    if (_disposed || _mounted || _failed) return;
    _mounted = true;
    final div = element as web.HTMLElement;
    div.id = _id;
    div.style.width = '${size.width}px';
    div.style.height = '${size.height}px';
    div.setAttribute('aria-label', 'Advertisement');
    try {
      _mount(div, _id.toJS, unit.toJS, size.width.toJS, size.height.toJS,
          _allowed, _event);
    } catch (_) {
      _received('bridge_unavailable');
    }
  }

  @override
  Widget get widget => SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: HtmlElementView.fromTagName(
          key: ValueKey(_id), tagName: 'div', onElementCreated: _created));

  void _destroySafely() {
    try {
      _destroy(_id.toJS);
    } catch (_) {/* Blocked scripts are harmless. */}
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    consent.removeListener(_consentChanged);
    _destroySafely();
    super.dispose();
  }
}

bool _denyPlacement(AdPlacement _) => false;
