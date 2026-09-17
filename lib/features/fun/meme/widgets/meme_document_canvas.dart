import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../meme_editor_controller.dart';
import '../models/meme_document.dart';
import '../rendering/meme_renderer.dart';

class MemeDocumentCanvas extends StatefulWidget {
  const MemeDocumentCanvas(
      {super.key,
      required this.editor,
      required this.cache,
      this.interactive = true});
  final MemeEditorController editor;
  final MemeImageCache cache;
  final bool interactive;
  @override
  State<MemeDocumentCanvas> createState() => _MemeDocumentCanvasState();
}

class _MemeDocumentCanvasState extends State<MemeDocumentCanvas> {
  MemeLayer? _startLayer;
  Offset? _startPoint;
  bool _dragging = false;

  String? _hit(Offset point, Size size) {
    for (final l in widget.editor.document.layers.reversed) {
      if (l.hidden || l.locked) continue;
      final center = Offset(
          (l.x + l.width / 2) * size.width, (l.y + l.height / 2) * size.height);
      final delta = point - center;
      final p = Offset(
          delta.dx * math.cos(-l.rotation) - delta.dy * math.sin(-l.rotation),
          delta.dx * math.sin(-l.rotation) + delta.dy * math.cos(-l.rotation));
      if (p.dx.abs() <= math.max(22, l.width * size.width / 2) &&
          p.dy.abs() <= math.max(22, l.height * size.height / 2)) {
        return l.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: Listenable.merge([widget.editor, widget.cache]),
      builder: (context, _) {
        final doc = widget.editor.document;
        return Semantics(
          label:
              'Editable meme canvas. Use the layer inspector for accessible positioning.',
          image: true,
          child: AspectRatio(
              aspectRatio: doc.layout.aspectRatio,
              child: LayoutBuilder(builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                final selected = widget.editor.selectedLayer;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.interactive
                      ? (d) =>
                          widget.editor.selectLayer(_hit(d.localPosition, size))
                      : null,
                  onScaleStart: !widget.interactive
                      ? null
                      : (d) {
                          widget.editor
                              .selectLayer(_hit(d.localFocalPoint, size));
                          _startLayer = widget.editor.selectedLayer;
                          _startPoint = d.localFocalPoint;
                          widget.editor.beginGesture();
                          setState(() => _dragging = true);
                        },
                  onScaleUpdate: !widget.interactive
                      ? null
                      : (d) {
                          final l = _startLayer;
                          if (l == null || l.locked) return;
                          final delta = d.localFocalPoint - _startPoint!;
                          final w = (l.width * d.scale).clamp(.035, 1.0);
                          final h = (l.height * d.scale).clamp(.035, 1.0);
                          var x =
                              (l.x + delta.dx / size.width + (l.width - w) / 2)
                                  .clamp(0.0, 1 - w);
                          var y = (l.y +
                                  delta.dy / size.height +
                                  (l.height - h) / 2)
                              .clamp(0.0, 1 - h);
                          if ((x + w / 2 - .5).abs() < .015) x = .5 - w / 2;
                          if ((y + h / 2 - .5).abs() < .015) y = .5 - h / 2;
                          widget.editor.updateLayer(l.copyWith(
                              x: x,
                              y: y,
                              width: w,
                              height: h,
                              rotation: (l.rotation + d.rotation)
                                  .clamp(-math.pi, math.pi)));
                        },
                  onScaleEnd: !widget.interactive
                      ? null
                      : (_) {
                          widget.editor.endGesture();
                          setState(() => _dragging = false);
                        },
                  child: Stack(fit: StackFit.expand, children: [
                    RepaintBoundary(
                        child: CustomPaint(
                            painter: MemePainter(doc, widget.cache.images))),
                    if (widget.interactive &&
                        selected != null &&
                        !selected.hidden)
                      Positioned(
                          left: selected.x * size.width,
                          top: selected.y * size.height,
                          width: selected.width * size.width,
                          height: selected.height * size.height,
                          child: IgnorePointer(
                              child: Transform.rotate(
                                  angle: selected.rotation,
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: const Color(0xff1498e5),
                                              width: 2)),
                                      child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                              width: 10,
                                              height: 10,
                                              color:
                                                  const Color(0xff1498e5))))))),
                    if (_dragging)
                      IgnorePointer(child: CustomPaint(painter: _Guides())),
                  ]),
                );
              })),
        );
      });
}

class _Guides extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0x991498e5)
      ..strokeWidth = 1;
    c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    c.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
