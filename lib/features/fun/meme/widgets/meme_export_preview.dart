import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/meme_document.dart';
import '../platform/meme_export_service.dart';
import '../storage/meme_store.dart';

class MemeExportPreview extends StatefulWidget {
  const MemeExportPreview(
      {super.key,
      required this.document,
      required this.png,
      this.backup,
      required this.exports,
      required this.store});
  final MemeDocument document;
  final Uint8List png;
  final Uint8List? backup;
  final MemeExportService exports;
  final MemeStore store;
  @override
  State<MemeExportPreview> createState() => _MemeExportPreviewState();
}

class _MemeExportPreviewState extends State<MemeExportPreview> {
  bool _busy = false;
  bool _preparingBackup = false;
  Uint8List? _backup;
  String? _backupError;
  String? _message;
  String? _historyWarning;

  @override
  void initState() {
    super.initState();
    _backup = widget.backup;
    if (_backup == null) unawaited(_prepareBackup());
  }

  Future<void> _prepareBackup() async {
    if (_preparingBackup) return;
    setState(() {
      _preparingBackup = true;
      _backupError = null;
    });
    try {
      final backup = await widget.store.exportBackup(widget.document);
      if (mounted) setState(() => _backup = backup);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _backupError = 'Project backup could not be prepared: $error\n'
                'Your PNG is ready. Retry the backup or continue editing to review the project photos.');
      }
    } finally {
      if (mounted) setState(() => _preparingBackup = false);
    }
  }

  Future<void> _run(Future<MemeTransferResult> action,
      {bool image = true}) async {
    setState(() {
      _busy = true;
      _historyWarning = null;
    });
    try {
      final result = await action;
      // The platform operation already finished. A failure to update local
      // recents cannot turn a completed Photos save or share into a failure.
      if (mounted) setState(() => _message = result.message);
      if (image && result.completed) {
        try {
          await widget.store.recordExport(MemeExportRecord(
              documentId: widget.document.id,
              fileName: safeMemeFileName(widget.document.name, 'png'),
              createdAt: DateTime.now(),
              width: widget.document.layout.pixelWidth,
              height: widget.document.layout.pixelHeight));
        } catch (_) {
          if (mounted) {
            setState(() => _historyWarning =
                'The transfer completed, but recent export history could not be updated on this device.');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not finish: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Rect _origin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your masterpiece is ready')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Forecast: Extremely Shareable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
              '${widget.document.layout.pixelWidth} × ${widget.document.layout.pixelHeight} • PNG',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 540, maxHeight: 600),
                  child: Image.memory(widget.png, fit: BoxFit.contain))),
          const SizedBox(height: 20),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_message!, textAlign: TextAlign.center)),
          if (_historyWarning != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_historyWarning!, textAlign: TextAlign.center)),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.exports
                            .savePng(widget.png, widget.document.name)),
                    icon: const Icon(Icons.download),
                    label: const Text('Save Image')),
                Builder(
                    builder: (c) => FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(widget.exports.sharePng(
                                widget.png, widget.document.name,
                                origin: _origin(c))),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share'))),
                Builder(
                    builder: (c) => OutlinedButton.icon(
                        onPressed: _busy || _preparingBackup
                            ? null
                            : _backup == null
                                ? _prepareBackup
                                : () => _run(
                                    widget.exports.saveBackup(
                                        _backup!, widget.document.name,
                                        origin: _origin(c)),
                                    image: false),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(_preparingBackup
                            ? 'Preparing project backup…'
                            : _backup == null
                                ? 'Retry Project Backup'
                                : 'Save Project Backup'))),
                OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Continue Editing')),
              ]),
          if (_backupError != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_backupError!, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          const Text(
              'A PNG is a finished image. A project backup keeps your layers and photos editable. Sharing opens your device’s share options.',
              textAlign: TextAlign.center),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
        ])),
      );
}
