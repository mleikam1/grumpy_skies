@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_update_sync.dart';
import 'package:web/web.dart' as web;

@JS('globalThis.fetch')
external JSFunction get _browserFetch;
@JS('globalThis.fetch')
external set _browserFetch(JSFunction value);

void main() {
  test(
      'browser static content omits even same-origin credentials and streams bytes',
      () async {
    final original = _browserFetch;
    addTearDown(() => _browserFetch = original);
    web.RequestInit? observed;
    const text = '{"content":"Public editorial pack"}';
    _browserFetch = ((JSAny input, web.RequestInit options) {
      observed = options;
      return Future.value(web.Response(
              text.toJS,
              web.ResponseInit(
                  status: 200,
                  headers: {
                    'content-type': 'application/json',
                    'content-length': utf8.encode(text).length.toString()
                  }.jsify() as web.HeadersInit)))
          .toJS;
    }).toJS;
    final download = await RoastHttpDownloader().call(
        Uri.parse('${web.window.location.origin}/content/roasts/test.json'),
        1024,
        2048);
    expect(utf8.decode(download.bytes), text);
    expect(observed!.credentials, 'omit');
    expect(observed!.redirect, 'error');
    expect(observed!.method, 'GET');
    await Future<void>.delayed(Duration.zero);
    expect(observed!.signal!.aborted, isTrue);
  });

  test(
      'stalled browser read aborts on timeout and releases scheduler for later sync',
      () async {
    final original = _browserFetch;
    addTearDown(() => _browserFetch = original);
    late web.ReadableStreamDefaultController pendingBody;
    var requests = 0;
    var aborted = false;
    var pendingRead = false;
    var installs = 0;
    var now = DateTime.utc(2026, 10, 10);
    _browserFetch = ((JSAny input, web.RequestInit options) {
      requests++;
      final web.Response response;
      if (requests == 1) {
        final source = {
          'start': ((web.ReadableStreamDefaultController controller) {
            pendingBody = controller;
          }).toJS,
          'pull': ((web.ReadableStreamDefaultController controller) {
            pendingRead = true; // Remain pending until fetch is aborted.
          }).toJS,
        }.jsify() as JSObject;
        final body = web.ReadableStream(source);
        options.signal!.addEventListener(
            'abort',
            ((web.Event event) {
              aborted = true;
              // Mirror fetch: aborting rejects a pending read of its response body.
              pendingBody
                  .error(web.DOMException('Request aborted', 'AbortError'));
            }).toJS);
        response = web.Response(
            body,
            web.ResponseInit(
                status: 200,
                headers: {'content-type': 'application/json'}.jsify()
                    as web.HeadersInit));
      } else {
        response = web.Response(
            jsonEncode({
              'schema_version': 1,
              'min_app_build': 1,
              'disabled_ids': [],
              'packs': [],
              'downloads_enabled': true,
            }).toJS,
            web.ResponseInit(
                status: 200,
                headers: {'content-type': 'application/json'}.jsify()
                    as web.HeadersInit));
      }
      return Future.value(response).toJS;
    }).toJS;
    addTearDown(() => pendingBody.error('test cleanup'.toJS));
    final downloader =
        RoastHttpDownloader(timeout: const Duration(milliseconds: 100));
    final scheduler = RoastUpdateScheduler(
        metadata: MemoryRoastUpdateMetadataStore(),
        fetcher: downloader.call,
        clock: () => now,
        jitter: () => Duration.zero);
    final policy = RoastUpdatePolicy(
        enabled: true,
        manifestUrl: Uri.parse('https://content.example/manifest.json'),
        allowedOrigins: {'https://content.example'});
    Future<RoastSyncResult> sync() => scheduler.run(
        policy: policy,
        install: (_, download) async {
          installs++;
          return 0;
        });
    final first =
        await sync().timeout(const Duration(seconds: 2), onTimeout: () {
      pendingBody.error('timeout cleanup'.toJS);
      throw StateError(
          'Downloader waited for read cancellation before aborting.');
    });
    expect(pendingRead, isTrue);
    expect(aborted, isTrue);
    expect(first.status, RoastSyncStatus.failed);
    expect(first.message, contains('TimeoutException'));
    expect(installs, 0);
    now = now.add(const Duration(days: 8));
    final second = await sync().timeout(const Duration(seconds: 2));
    expect(second.status, RoastSyncStatus.unchanged);
    expect(installs, 1);
    expect(requests, 2);
  });
}
