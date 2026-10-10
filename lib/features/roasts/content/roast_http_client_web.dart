import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createRoastHttpClient() => CookielessRoastClient();

/// Public static content always omits credentials, including same-origin
/// cookies. Streamed browser decoding is consumed once by the bounded downloader.
class CookielessRoastClient extends http.BaseClient {
  final _requests = <web.AbortController>{};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Roast HTTP client is closed.');
    if (request.method != 'GET') {
      throw http.ClientException('Roast content permits GET only.');
    }
    await request.finalize().drain<void>();
    final abort = web.AbortController();
    _requests.add(abort);
    if (request is http.AbortableRequest) {
      // Dart interop methods cannot be torn off.
      request.abortTrigger?.whenComplete(() => abort.abort());
    }
    try {
      final response = await web.window
          .fetch(
              request.url.toString().toJS,
              web.RequestInit(
                method: 'GET',
                credentials: 'omit',
                redirect: 'error',
                signal: abort.signal,
                headers:
                    {'accept': 'application/json'}.jsify() as web.HeadersInit,
              ))
          .toDart;
      final headers = <String, String>{};
      for (final name in [
        'content-type',
        'content-length',
        'content-encoding'
      ]) {
        final value = response.headers.get(name);
        if (value != null) headers[name] = value;
      }
      return http.StreamedResponse(_body(response, abort), response.status,
          request: request,
          headers: headers,
          contentLength: int.tryParse(headers['content-length'] ?? ''));
    } catch (_) {
      abort.abort();
      _requests.remove(abort);
      throw http.ClientException('Roast content request failed.', request.url);
    }
  }

  Stream<List<int>> _body(
      web.Response response, web.AbortController abort) async* {
    final reader =
        response.body?.getReader() as web.ReadableStreamDefaultReader?;
    var complete = false;
    try {
      if (reader == null) return;
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) {
          complete = true;
          break;
        }
        yield (chunk.value as JSUint8Array).toDart;
      }
    } catch (_) {
      // An abort rejects a pending JS read. When the downloader already emitted
      // its timeout, the subscription is canceling; do not leak a second error.
      if (!abort.signal.aborted) rethrow;
    } finally {
      if (!complete) {
        abort.abort();
        try {
          await reader?.cancel().toDart;
        } catch (_) {/* Already aborted. */}
      }
      _requests.remove(abort);
    }
  }

  @override
  void close() {
    _closed = true;
    for (final request in _requests.toList()) {
      request.abort();
    }
    _requests.clear();
  }
}
