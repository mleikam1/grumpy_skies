import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'meme_raster.dart';

/// Limits document-level browser drop listeners to this visible widget's bounds.
class MemeDropZone extends StatefulWidget {
  const MemeDropZone(
      {super.key,
      required this.child,
      required this.onBytes,
      required this.onError,
      this.enabled = true});
  final Widget child;
  final ValueChanged<Uint8List> onBytes;
  final ValueChanged<String> onError;
  final bool enabled;
  @override
  State<MemeDropZone> createState() => _MemeDropZoneState();
}

class _MemeDropZoneState extends State<MemeDropZone> {
  late final JSFunction _over;
  late final JSFunction _drop;
  bool _contains(web.DragEvent event) {
    if (!mounted || !widget.enabled) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final position = box.globalToLocal(
        Offset(event.clientX.toDouble(), event.clientY.toDouble()));
    return (Offset.zero & box.size).contains(position);
  }

  @override
  void initState() {
    super.initState();
    _over = ((web.DragEvent event) {
      if (_contains(event)) event.preventDefault();
    }).toJS;
    _drop = ((web.DragEvent event) {
      if (!_contains(event)) return;
      event.preventDefault();
      final files = event.dataTransfer?.files;
      if (files == null || files.length == 0) return;
      if (files.length > 1) {
        widget.onError('Drop one photo at a time.');
        return;
      }
      final file = files.item(0)!;
      if (file.size > memeMaxImportBytes) {
        widget.onError('Choose a photo smaller than 20 MB.');
        return;
      }
      file.arrayBuffer().toDart.then((buffer) {
        if (mounted) widget.onBytes(buffer.toDart.asUint8List());
      }).catchError((Object _) {
        if (mounted) {
          widget.onError('This photo could not be opened. Try Upload Photo.');
        }
      });
    }).toJS;
    web.document.addEventListener('dragover', _over);
    web.document.addEventListener('drop', _drop);
  }

  @override
  void dispose() {
    web.document.removeEventListener('dragover', _over);
    web.document.removeEventListener('drop', _drop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
