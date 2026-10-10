import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/network_counters.dart';
import 'roast_http_client.dart'
    if (dart.library.js_interop) 'roast_http_client_web.dart';

/// Opt-in only after the existing static Hosting target and origin are verified.
class RoastUpdatePolicy {
  const RoastUpdatePolicy({
    this.enabled = false,
    this.manifestUrl,
    this.allowedOrigins = const {},
    this.appBuild = 1,
    this.rollingBudgetBytes = 1024 * 1024,
    this.maxManifestBytes = 4096,
    this.maxTransferBytes = 256 * 1024,
    this.maxDecodedBytes = 2 * 1024 * 1024,
  });
  final bool enabled;
  final Uri? manifestUrl;
  final Set<String> allowedOrigins;
  final int appBuild;
  final int rollingBudgetBytes;
  final int maxManifestBytes;
  final int maxTransferBytes;
  final int maxDecodedBytes;
  static const disabled = RoastUpdatePolicy();

  void validateUrl(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !allowedOrigins.contains(uri.origin)) {
      throw const FormatException('Roast update URL is not allowlisted HTTPS.');
    }
  }
}

class RoastDownload {
  const RoastDownload(this.bytes, this.accountedBytes);
  final Uint8List bytes;

  /// Conservative payload accounting, including a fixed HTTP overhead allowance.
  final int accountedBytes;
}

typedef RoastDownloadFetcher = Future<RoastDownload> Function(
    Uri uri, int maxTransferBytes, int maxDecodedBytes);

/// Limits before allocation and while streaming; no redirects or retries.
class RoastHttpDownloader {
  RoastHttpDownloader(
      {http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client;
  http.Client? _client;

  /// Maximum wait for response headers or the next body chunk.
  final Duration timeout;
  Future<RoastDownload> call(Uri uri, int maxTransfer, int maxDecoded) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false;
    http.StreamedResponse? response;
    var reading = false;
    try {
      response = await (_client ??= createRoastHttpClient())
          .send(request)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw FormatException('Roast download HTTP ${response.statusCode}.');
      }
      final mime = response.headers['content-type'] ?? '';
      if (!mime.toLowerCase().contains('application/json')) {
        throw const FormatException('Roast update is not JSON.');
      }
      final transferLength =
          int.tryParse(response.headers['content-length'] ?? '');
      if (transferLength != null &&
          (transferLength < 0 || transferLength > maxTransfer)) {
        throw const FormatException('Roast transfer exceeds limit.');
      }
      final encoding = response.headers['content-encoding']?.toLowerCase();
      final compressed = encoding == 'gzip' || encoding == 'br';
      final bytes = BytesBuilder(copy: false);
      reading = true;
      await for (final chunk
          in response.stream.timeout(timeout, onTimeout: (sink) {
        // Abort before emitting the timeout: canceling an async* browser stream
        // waits for its pending reader.read(), which itself needs this abort.
        if (!abort.isCompleted) abort.complete();
        sink.addError(TimeoutException('Roast download timed out.', timeout));
        sink.close();
      })) {
        // Without a trustworthy wire length (common in browsers), use the decoded
        // size as the conservative transfer upper bound.
        final limit = compressed && transferLength != null
            ? maxDecoded
            : min(maxTransfer, maxDecoded);
        if (bytes.length + chunk.length > limit) {
          throw const FormatException('Roast decoded payload exceeds limit.');
        }
        bytes.add(chunk);
      }
      final accounted = (compressed && transferLength != null
              ? transferLength
              : max(transferLength ?? 0, bytes.length)) +
          1024;
      return RoastDownload(bytes.takeBytes(), accounted);
    } finally {
      // Timeout and header rejection must terminate the request, not merely
      // stop awaiting a response while traffic continues outside the budget.
      if (!abort.isCompleted) abort.complete();
      if (response != null && !reading) {
        await response.stream.listen((_) {}).cancel();
      }
    }
  }
}

abstract interface class RoastUpdateMetadataStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> state);
}

class PreferencesRoastUpdateMetadataStore implements RoastUpdateMetadataStore {
  static const _key = 'roast_updates_metadata_v2';
  @override
  Future<Map<String, dynamic>> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, dynamic> state) async {
    final ok = await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(state));
    if (!ok) throw StateError('Cannot persist roast update budget.');
  }
}

class MemoryRoastUpdateMetadataStore implements RoastUpdateMetadataStore {
  Map<String, dynamic> state = {};
  @override
  Future<Map<String, dynamic>> read() async =>
      (jsonDecode(jsonEncode(state)) as Map).cast<String, dynamic>();
  @override
  Future<void> write(Map<String, dynamic> value) async =>
      state = (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
}

enum RoastSyncStatus {
  disabled,
  throttled,
  updated,
  unchanged,
  budgetExhausted,
  failed
}

class RoastSyncResult {
  const RoastSyncResult(this.status, {this.message, this.installed = 0});
  final RoastSyncStatus status;
  final String? message;
  final int installed;
}

/// Scheduler is called explicitly during eligible foreground use, never by a
/// selector, widget build, persona switch, timer, or background listener.
class RoastUpdateScheduler {
  RoastUpdateScheduler({
    RoastUpdateMetadataStore? metadata,
    RoastDownloadFetcher? fetcher,
    DateTime Function()? clock,
    Duration Function()? jitter,
    NetworkCounters? counters,
  })  : metadata = metadata ?? PreferencesRoastUpdateMetadataStore(),
        fetcher = fetcher ?? RoastHttpDownloader().call,
        clock = clock ?? DateTime.now,
        jitter = jitter ?? (() => Duration(minutes: Random().nextInt(1441))),
        counters = counters ?? NetworkCounters.instance;
  final RoastUpdateMetadataStore metadata;
  final RoastDownloadFetcher fetcher;
  final DateTime Function() clock;
  final Duration Function() jitter;
  final NetworkCounters counters;
  Future<RoastSyncResult>? _inflight;

  Future<RoastSyncResult> run({
    required RoastUpdatePolicy policy,
    required Future<int> Function(Map<String, dynamic> manifest,
            Future<String> Function(Uri, int) download)
        install,
  }) {
    if (!policy.enabled) {
      return Future.value(const RoastSyncResult(RoastSyncStatus.disabled));
    }
    return _inflight ??=
        _run(policy, install).whenComplete(() => _inflight = null);
  }

  Future<RoastSyncResult> _run(
      RoastUpdatePolicy policy,
      Future<int> Function(
              Map<String, dynamic>, Future<String> Function(Uri, int))
          install) async {
    Map<String, dynamic>? state;
    try {
      if (policy.rollingBudgetBytes <= 0 ||
          policy.maxManifestBytes <= 0 ||
          policy.maxTransferBytes <= 0 ||
          policy.maxDecodedBytes <= 0) {
        throw const FormatException('Roast update limits must be positive.');
      }
      if (policy.manifestUrl == null) {
        throw StateError('No verified manifest URL.');
      }
      policy.validateUrl(policy.manifestUrl!);
      state = await metadata.read();
      final now = clock().toUtc();
      final next = DateTime.tryParse(state['next'] as String? ?? '');
      final last = DateTime.tryParse(state['attempt'] as String? ?? '');
      if ((next != null && now.isBefore(next)) ||
          (last != null && now.difference(last) < const Duration(days: 7))) {
        return const RoastSyncResult(RoastSyncStatus.throttled);
      }
      state['attempt'] = now.toIso8601String();
      state['next'] =
          now.add(const Duration(days: 7)).add(jitter()).toIso8601String();
      await metadata.write(state); // A crash still counts as an attempt.
      Future<String> download(Uri uri, int maxDecoded) async {
        policy.validateUrl(uri);
        final isManifest = uri == policy.manifestUrl;
        final maximum =
            isManifest ? policy.maxManifestBytes : policy.maxTransferBytes;
        const overhead = 1024;
        final ledger = ((state!['ledger'] as List?) ?? [])
            .whereType<Map>()
            .where((entry) {
              final at = DateTime.tryParse(entry['at'] as String? ?? '');
              return at != null &&
                  (now.difference(at) < const Duration(days: 30));
            })
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        final used = ledger.fold<int>(0, (sum, v) => sum + (v['bytes'] as int));
        if (used + maximum + overhead > policy.rollingBudgetBytes) {
          throw const _RoastBudgetExceeded();
        }
        final reservation = {
          'at': now.toIso8601String(),
          'bytes': maximum + overhead
        };
        ledger.add(reservation);
        state['ledger'] = ledger;
        await metadata.write(state); // Reserve before any network activity.
        counters.increment('roastUpdateReservedBytes', maximum + overhead);
        counters.increment(
            isManifest ? 'roastManifestRequests' : 'roastPackRequests');
        final response = await fetcher(uri, maximum, maxDecoded);
        if (response.bytes.length > maxDecoded ||
            response.accountedBytes > maximum + overhead) {
          throw const FormatException('Roast download exceeds allowed size.');
        }
        reservation['bytes'] = max(response.accountedBytes, overhead);
        await metadata.write(state);
        counters.increment(
            'roastUpdateAccountedBytes', response.accountedBytes);
        return utf8.decode(response.bytes);
      }

      final raw = await download(policy.manifestUrl!, policy.maxManifestBytes);
      final manifest = (jsonDecode(raw) as Map).cast<String, dynamic>();
      const allowedKeys = {
        'schema_version',
        'min_app_build',
        'disabled_ids',
        'packs',
        'downloads_enabled'
      };
      const allowedPackKeys = {
        'persona',
        'locale',
        'version',
        'url',
        'sha256',
        'bytes',
        'min_app_build'
      };
      if (manifest.keys.any((key) => !allowedKeys.contains(key))) {
        throw const FormatException('Unknown roast manifest field.');
      }
      for (final entry in manifest['packs'] as List? ?? const []) {
        if (entry is! Map ||
            entry.keys.any((key) => !allowedPackKeys.contains(key))) {
          throw const FormatException('Unknown roast manifest pack field.');
        }
      }
      if (manifest['schema_version'] != 1 ||
          (manifest['min_app_build'] as num? ?? 1) > policy.appBuild) {
        throw const FormatException('Incompatible roast manifest.');
      }
      if (manifest['disabled_ids'] is! List || manifest['packs'] is! List) {
        throw const FormatException('Invalid roast manifest.');
      }
      state['disabled_ids'] = (manifest['disabled_ids'] as List).cast<String>();
      await metadata.write(state);
      if (manifest['downloads_enabled'] == false) {
        state['failures'] = 0;
        await metadata.write(state);
        return const RoastSyncResult(RoastSyncStatus.unchanged);
      }
      final count = await install(manifest, download);
      state['failures'] = 0;
      await metadata.write(state);
      return RoastSyncResult(
          count == 0 ? RoastSyncStatus.unchanged : RoastSyncStatus.updated,
          installed: count);
    } catch (error) {
      if (state != null) {
        final failures = min((state['failures'] as int? ?? 0) + 1, 4);
        state['failures'] = failures;
        state['next'] = clock()
            .toUtc()
            .add(Duration(days: 7 * (1 << (failures - 1))))
            .add(jitter())
            .toIso8601String();
        try {
          await metadata.write(state);
        } catch (_) {/* fail closed */}
      }
      return RoastSyncResult(
          error is _RoastBudgetExceeded
              ? RoastSyncStatus.budgetExhausted
              : RoastSyncStatus.failed,
          message: error.toString());
    }
  }
}

class _RoastBudgetExceeded {
  const _RoastBudgetExceeded();
}
