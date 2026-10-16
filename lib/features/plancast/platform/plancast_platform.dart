import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Narrow native boundary. Calendar bodies never leave the device through this
/// channel; weather/location service calls belong to the repository above it.
class PlanCastPlatform {
  PlanCastPlatform(
      {MethodChannel? channel, EventChannel? eventChannel, bool? supported})
      : _channel = channel ?? const MethodChannel('grumpy_skies/plancast'),
        _events =
            eventChannel ?? const EventChannel('grumpy_skies/plancast/changes'),
        supported = supported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android));

  final MethodChannel _channel;
  final EventChannel _events;
  final bool supported;
  bool get isSupported => supported;
  Stream<String>? _changes;

  Future<T?> _invoke<T>(String method,
      [Map<String, dynamic>? arguments]) async {
    if (!supported) return null;
    // Older installations / unsupported hosts remain a working weather app.
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  Future<String> calendarPermission() async =>
      await _invoke<String>('calendarPermission') ?? 'unsupported';
  Future<String> requestCalendarPermission() async =>
      await _invoke<String>('requestCalendarPermission') ?? 'unsupported';
  Future<List<Map<String, dynamic>>> calendars() async =>
      _maps(await _invoke<List<dynamic>>('calendars'));
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    if (calendarIds.isEmpty) return const [];
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 16)) {
      throw ArgumentError(
          'PlanCast calendar queries must be bounded to 16 days.');
    }
    return _maps(await _invoke<List<dynamic>>('events', {
      'calendarIds': calendarIds,
      'startMs': start.toUtc().millisecondsSinceEpoch,
      'endMs': end.toUtc().millisecondsSinceEpoch
    }));
  }

  static List<Map<String, dynamic>> _maps(List<dynamic>? values) =>
      (values ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  Stream<String> get changes => !supported
      ? const Stream.empty()
      : _changes ??= _events
          .receiveBroadcastStream()
          .where((event) => event is String)
          .cast<String>()
          .handleError((Object _) {});
  Future<void> startObserving() async {
    await _invoke<void>('startObserving');
  }

  Future<void> stopObserving() async {
    await _invoke<void>('stopObserving');
  }

  Future<String?> secureRead() => _invoke<String>('secureRead');
  Future<void> secureWrite(String value) async {
    await _invoke<void>('secureWrite', {'value': value});
  }

  Future<void> secureDelete() async {
    await _invoke<void>('secureDelete');
  }

  /// Removes only PlanCast data, jobs, observers, speech and notifications.
  Future<void> disconnect() async {
    await _invoke<void>('disconnect');
  }

  Future<String> notificationPermission() async =>
      await _invoke<String>('notificationPermission') ?? 'unsupported';
  Future<String> requestNotificationPermission() async =>
      await _invoke<String>('requestNotificationPermission') ?? 'unsupported';
  Future<void> replaceNotifications(List<Map<String, dynamic>> notices) async {
    await _invoke<void>(
        'replaceNotifications', {'notices': notices.take(32).toList()});
  }

  Future<String> speechStatus() async =>
      await _invoke<String>('speechStatus') ?? 'unavailable';
  Future<bool> speak(String text) async =>
      await _invoke<bool>('speak', {'text': text}) ?? false;
  Future<void> stopSpeaking() async {
    await _invoke<void>('stopSpeaking');
  }

  Future<String?> consumeNotificationRoute() =>
      _invoke<String>('consumeNotificationRoute');
}
