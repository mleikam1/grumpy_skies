import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports actual viewport exposure, including nested scroll clips, background
/// lifecycle, inactive tabs and routes covered by a modal on an outer Navigator.
///
/// Checks are batched after frames the app already produces. This observer never
/// requests periodic frames or owns a ticker, and only rebuilds on a transition.
/// It also works for retained/offscreen list children that TickerMode alone misses.
class ActiveViewport extends StatefulWidget {
  const ActiveViewport({
    super.key,
    this.child,
    this.builder,
    this.onActiveChanged,
    this.onExposure,
    this.observeParentWhenEmpty = false,
    this.minimumVisibleFraction = .01,
  })  : assert(child != null || builder != null),
        assert(minimumVisibleFraction > 0 && minimumVisibleFraction <= 1);

  final Widget? child;
  final Widget Function(BuildContext context, bool active, Widget? child)?
      builder;
  final ValueChanged<bool>? onActiveChanged;

  /// Runs after actual exposure measurement, even when visibility is unchanged.
  final ValueChanged<bool>? onExposure;
  final bool observeParentWhenEmpty;
  final double minimumVisibleFraction;

  @override
  State<ActiveViewport> createState() => _ActiveViewportState();
}

class _ActiveViewportState extends State<ActiveViewport>
    with WidgetsBindingObserver {
  final _boundsKey = GlobalKey();
  final _routes = <ModalRoute<dynamic>>[];
  bool _active = false;
  bool _tickerEnabled = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _ExposureFrames.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _routes.clear();
    BuildContext? routeContext = context;
    final navigators = <NavigatorState>{};
    while (routeContext != null) {
      final route = ModalRoute.of(routeContext);
      if (route != null && !_routes.contains(route)) _routes.add(route);
      final navigator = Navigator.maybeOf(routeContext);
      if (navigator == null || !navigators.add(navigator)) break;
      routeContext = navigator.context;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = _isForeground(state);
    if (!_foreground) {
      _setActive(false);
    } else {
      // A resume may arrive before its first frame. Recheck after layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkExposure());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  static bool _isForeground(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  void _checkExposure() {
    if (!mounted) return;
    _setActive(_foreground &&
        _tickerEnabled &&
        _routes.every((route) => route.isCurrent) &&
        _visibleFraction() >= widget.minimumVisibleFraction);
    widget.onExposure?.call(_active);
  }

  double _visibleFraction() {
    var box = _boundsKey.currentContext?.findRenderObject();
    if (widget.observeParentWhenEmpty) {
      while (box is RenderBox && box.hasSize && box.size.isEmpty) {
        box = box.parent;
      }
    }
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return 0;
    }
    final bounds = MatrixUtils.transformRect(
        box.getTransformTo(null), Offset.zero & box.size);
    if (!bounds.isFinite || bounds.isEmpty) return 0;
    final view = View.of(context);
    var visible = bounds
        .intersect(Offset.zero & (view.physicalSize / view.devicePixelRatio));
    RenderObject child = box;
    RenderObject? ancestor = child.parent;
    while (ancestor != null && !visible.isEmpty) {
      if (ancestor is RenderOffstage && ancestor.offstage) return 0;
      if (ancestor is RenderOpacity && ancestor.opacity == 0) return 0;
      if (ancestor is RenderIndexedStack) {
        var paintedChild = ancestor.firstChild;
        for (var index = 0; index < (ancestor.index ?? -1); index++) {
          paintedChild =
              paintedChild == null ? null : ancestor.childAfter(paintedChild);
        }
        if (ancestor.index == null || child != paintedChild) return 0;
      }
      final clip = ancestor.describeApproximatePaintClip(child);
      if (clip != null) {
        visible = visible.intersect(
            MatrixUtils.transformRect(ancestor.getTransformTo(null), clip));
      }
      child = ancestor;
      ancestor = ancestor.parent;
    }
    if (visible.isEmpty) return 0;
    return (visible.width * visible.height / (bounds.width * bounds.height))
        .clamp(0, 1);
  }

  void _setActive(bool value) {
    if (!mounted || value == _active) return;
    if (widget.builder != null) {
      setState(() => _active = value);
    } else {
      _active = value;
    }
    widget.onActiveChanged?.call(value);
  }

  @override
  void dispose() {
    _ExposureFrames.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        key: _boundsKey,
        child: widget.builder?.call(context, _active, widget.child) ??
            widget.child,
      );
}

abstract final class _ExposureFrames {
  static final _observers = <_ActiveViewportState>{};
  static bool _installed = false;

  static void add(_ActiveViewportState state) {
    _observers.add(state);
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_observers.isEmpty) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final observer in _observers.toList(growable: false)) {
          observer._checkExposure();
        }
      });
    });
  }

  static void remove(_ActiveViewportState state) => _observers.remove(state);
}
