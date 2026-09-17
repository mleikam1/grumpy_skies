import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../ad_placement.dart';
import '../ad_reporting.dart';
import '../monetization_controller.dart';
import '../platform/ad_platform.dart';

/// One owned SDK/DOM slot per section visit. No requests from build, no refresh.
class AdSection extends StatefulWidget {
  const AdSection(
      {super.key,
      required this.placement,
      this.contentCount = 1,
      this.sample = false,
      this.available = true});
  final AdPlacement placement;
  final int contentCount;
  final bool sample, available;
  @override
  State<AdSection> createState() => _AdSectionState();
}

class _AdSectionState extends State<AdSection> {
  static int _visits = 0;
  late final String _visit = 'section-${++_visits}';
  final GlobalKey _anchor = GlobalKey();
  MonetizationController? _controller;
  ScrollPosition? _scroll;
  DisplayAdHandle? _ad;
  DisplaySize? _size;
  String? _aside;
  double _heldHeight = 0;
  bool _loading = false, _attempted = false, _scheduled = false;
  bool _collapsePending = false;
  final Set<int> _pointers = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<MonetizationController?>();
    if (_controller != controller) {
      _controller?.removeListener(_schedule);
      _controller = controller;
      controller?.addListener(_schedule);
    }
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scroll != scroll) {
      _scroll?.removeListener(_schedule);
      _scroll?.isScrollingNotifier.removeListener(_schedule);
      _scroll = scroll;
      scroll?.addListener(_schedule);
      scroll?.isScrollingNotifier.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(AdSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) _retire();
    _schedule();
  }

  void _pointer(PointerEvent event) {
    if (event is PointerDownEvent) _pointers.add(event.pointer);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (_collapsePending && _pointers.isEmpty) _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _evaluate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _contentEligible =>
      hasEligibleContent(widget.placement, widget.contentCount,
          sample: widget.sample, available: widget.available);

  void _evaluate() {
    final controller = _controller;
    final box = _anchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final size = DisplaySize.forPlacement(widget.placement, box.size.width);
    final origin = box.localToGlobal(Offset.zero);
    final Object? viewport = RenderAbstractViewport.maybeOf(box);
    Rect visibleBounds = Offset.zero & MediaQuery.sizeOf(context);
    if (viewport is RenderBox && viewport.hasSize) {
      visibleBounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    }
    final visible = origin.dy < visibleBounds.bottom &&
        origin.dy + (size?.height ?? 1) > visibleBounds.top;
    final allowed = controller != null &&
        controller.displayAllowed(widget.placement) &&
        _contentEligible &&
        size != null &&
        ModalRoute.of(context)?.isCurrent != false &&
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        View.of(context).viewInsets.bottom == 0;
    if (!allowed ||
        (!visible && (_loading || _ad != null)) ||
        (_size != null && size != _size)) {
      _retire();
      return;
    }
    if (_collapsePending &&
        _pointers.isEmpty &&
        !(_scroll?.isScrollingNotifier.value ?? false)) {
      setState(() {
        _collapsePending = false;
        _size = null;
        _aside = null;
      });
    }
    if (!allowed || !visible || _attempted) return;
    _attempted = true;
    final generation = ++_generation;
    controller.reporter
        .report(AdEvent(AdEventKind.opportunity, widget.placement));
    setState(() {
      _loading = true;
      _size = size;
    });
    unawaited(_load(controller, size, generation));
  }

  Future<void> _load(MonetizationController controller, DisplaySize size,
      int generation) async {
    final ad = await controller.loadDisplay(widget.placement, size);
    if (!mounted ||
        generation != _generation ||
        !controller.displayAllowed(widget.placement)) {
      ad?.dispose();
      return;
    }
    if (ad == null) {
      _retire();
      return;
    }
    final aside = await controller.asideForVisit(_visit);
    if (!mounted ||
        generation != _generation ||
        !controller.displayAllowed(widget.placement)) {
      ad.dispose();
      return;
    }
    if (ad is DeferredDisplayAdHandle) {
      ad.stateChanges.addListener(_deferredChanged);
    }
    setState(() {
      _ad = ad;
      _aside = aside;
      _loading = false;
    });
    _schedule();
  }

  void _deferredChanged() {
    final ad = _ad;
    if (mounted && ad is DeferredDisplayAdHandle && ad.failed) _retire();
  }

  void _releaseAd() {
    final ad = _ad;
    if (ad is DeferredDisplayAdHandle) {
      ad.stateChanges.removeListener(_deferredChanged);
    }
    ad?.dispose();
    _ad = null;
  }

  void _retire() {
    _generation++;
    _releaseAd();
    _loading = false;
    final box = _anchor.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && !_collapsePending) {
      _heldHeight = box.size.height;
    }
    if (_size == null) return;
    final defer =
        _pointers.isNotEmpty || (_scroll?.isScrollingNotifier.value ?? false);
    setState(() {
      _collapsePending = defer;
      _aside = null;
      if (!defer) {
        _size = null;
        _aside = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        key: _anchor,
        width: double.infinity,
        child: _size == null
            ? const SizedBox(height: 1)
            : _collapsePending
                ? SizedBox(height: _heldHeight)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_aside != null) ...[
                        Text(_aside!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
                        const Divider(height: 24),
                      ],
                      const Text('Advertisements'),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: _size!.width.toDouble(),
                          height: _size!.height.toDouble(),
                          child: _ad?.widget ?? const SizedBox.shrink()),
                    ]),
                  ));
  }

  @override
  void dispose() {
    _generation++;
    _releaseAd();
    _controller?.removeListener(_schedule);
    _scroll?.removeListener(_schedule);
    _scroll?.isScrollingNotifier.removeListener(_schedule);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    super.dispose();
  }
}
