// Run as a Flutter WEB APP, never as production main.dart. This deliberately
// injects a fake GPT implementation, with no Google tag/network/paid inventory.
// flutter run -d web-server -t integration_test/web_ad_harness.dart --web-port 8768
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/ad_reporting.dart';
import 'package:grumpy_skies/monetization/platform/ad_platform.dart';
import 'package:grumpy_skies/monetization/platform/web_ad_consent.dart';
import 'package:grumpy_skies/monetization/platform/web_display_adapter.dart';

@JS('eval')
external JSAny? evaluate(JSString source);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  evaluate(r'''
(() => {
 const listeners = new Map(), slots = new Map();
 window.daymakerHarness = {requests:0, destroys:0, connected:false, width:0, height:0, noFill:false};
 const pubads = {
   addEventListener(name, fn) { if(!listeners.has(name)) listeners.set(name,new Set()); listeners.get(name).add(fn); },
   removeEventListener(name, fn) { listeners.get(name)?.delete(fn); }
 };
 window.googletag = {
   apiReady:true, cmd:{push(fn){fn();}}, pubads:()=>pubads, enableServices(){},
   defineSlot(unit,size,id) {const slot={id,size,addService(){return slot;}};slots.set(id,slot);return slot;},
   display(element) {
     const slot=slots.get(element.id), h=window.daymakerHarness;
     h.requests++;h.connected=element.isConnected;
     const r=element.getBoundingClientRect();h.width=r.width;h.height=r.height;
     if (!h.noFill) {
       const fixture=document.createElement('div');fixture.textContent='MOCK PROVIDER\n300 × 250\nNO ADS SERVED';
       fixture.style.cssText='width:100%;height:100%;box-sizing:border-box;display:flex;align-items:center;justify-content:center;white-space:pre-line;background:#d4f5df;color:#123d29;font:700 20px sans-serif;text-align:center;border:2px solid #286344';
       element.appendChild(fixture);
     }
     queueMicrotask(()=>{ for(const f of listeners.get('slotRenderEnded')||[]) f({slot,isEmpty:h.noFill}); });
   },
   destroySlots(list) { for(const slot of list){window.daymakerHarness.destroys++;slots.delete(slot.id);}return true;}
 };
})();
'''
      .toJS);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Harness()));
}

class Harness extends StatefulWidget {
  const Harness({super.key});
  @override
  State<Harness> createState() => _HarnessState();
}

class _HarnessState extends State<Harness> implements AdReporter {
  final _consent = _HarnessConsent();
  DeferredDisplayAdHandle? _handle;
  final _events = <String>[];
  int _rebuilds = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await WebDisplayAdapter(
            consent: _consent, placementAllowed: (_) => true)
        .load(
            unitId: '/123456/daymaker_fixture',
            size: const DisplaySize(300, 250),
            placement: AdPlacement.memeLibraryMrec,
            reporter: this);
    if (!mounted) {
      result?.dispose();
      return;
    }
    final handle = result as DeferredDisplayAdHandle?;
    setState(() => _handle = handle);
    handle?.stateChanges.addListener(() {
      if (handle.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_handle, handle)) {
            setState(() => _handle = null);
          }
          handle.dispose();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }
    });
  }

  @override
  void report(AdEvent event) {
    _events.add(
        '${event.kind.name}${event.reason == null ? '' : ': ${event.reason}'}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String get _status => evaluate('JSON.stringify(window.daymakerHarness)'.toJS)
      .dartify()
      .toString();
  void _remove() {
    _handle?.dispose();
    setState(() => _handle = null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Web display integration • fake GPT')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'REAL FLUTTER DOM VIEW • SIMULATED PROVIDER • NO PAID INVENTORY',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Rebuilds: $_rebuilds'),
            Text('DOM / driver status: $_status'),
            Text('Events: ${_events.join(' → ')}'),
            const SizedBox(height: 24),
            if (_handle != null) ...[
              const Text('Advertisements', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(child: _handle!.widget),
              const SizedBox(height: 24)
            ],
            if (_handle == null)
              const Text('Slot removed. No orphaned advertising label.'),
            Wrap(spacing: 12, runSpacing: 12, children: [
              ElevatedButton(
                  onPressed: () => setState(() => _rebuilds++),
                  child: const Text('Rebuild')),
              ElevatedButton(
                  onPressed: _consent.revoke,
                  child: const Text('Revoke consent')),
              ElevatedButton(
                  onPressed: _remove, child: const Text('Remove slot')),
              ElevatedButton(
                  onPressed: () {
                    _remove();
                    _consent.allow();
                    evaluate('daymakerHarness.noFill=true'.toJS);
                    _load();
                  },
                  child: const Text('Test no fill')),
            ]),
            const SizedBox(height: 16),
            const Text(
                'Verify: connected true, 300×250 DOM, request then loaded (no impression inferred), rebuild retains one request, consent/no-fill detach the complete section.'),
          ])));
  @override
  void dispose() {
    _handle?.dispose();
    _consent.dispose();
    super.dispose();
  }
}

class _HarnessConsent extends WebAdConsent {
  bool _allowed = true;
  @override
  bool get cmpConfigured => true;
  @override
  bool get resolved => true;
  @override
  bool get canRequestAds => _allowed;
  void revoke() {
    _allowed = false;
    notifyListeners();
  }

  void allow() {
    _allowed = true;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> showPrivacyOptions() async {}
}
