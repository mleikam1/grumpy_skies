import 'dart:typed_data';
import 'package:flutter/widgets.dart';

class MemeDropZone extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
