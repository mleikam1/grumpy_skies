import 'plancast_models.dart';
import 'platform/plancast_platform.dart';

/// Read-only contract. Implementations never receive event writes.
abstract class CalendarRepository {
  const CalendarRepository();
  bool get supported;
  Stream<String> get changes;
  Future<String> permission();
  Future<String> requestPermission();
  Future<List<DeviceCalendar>> calendars();
  Future<List<CalendarEvent>> events(
      {required Set<String> calendarIds,
      required DateTime start,
      required DateTime end});
  Future<void> startObserving();
  Future<void> stopObserving();
}

class DeviceCalendarRepository extends CalendarRepository {
  const DeviceCalendarRepository(this.platform);
  final PlanCastPlatform platform;
  @override
  bool get supported => platform.supported;
  @override
  Stream<String> get changes => platform.changes;
  @override
  Future<String> permission() => platform.calendarPermission();
  @override
  Future<String> requestPermission() => platform.requestCalendarPermission();
  @override
  Future<List<DeviceCalendar>> calendars() async =>
      (await platform.calendars()).map(DeviceCalendar.fromMap).toList();
  @override
  Future<List<CalendarEvent>> events(
      {required Set<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    if (calendarIds.isEmpty || await permission() != 'authorized') {
      return const [];
    }
    final records = await platform.events(
        calendarIds: calendarIds.toList(), start: start, end: end);
    final instances = <String, CalendarEvent>{};
    for (final record in records) {
      final event = CalendarEvent.fromMap(record);
      if (event == null || !calendarIds.contains(event.calendarId)) continue;
      if (!event.endUtc.isAfter(start) || !event.startUtc.isBefore(end)) {
        continue;
      }
      // Different overlapping events remain distinct; only duplicate instances
      // of the same native event at the same instant are collapsed.
      instances[event.id] = event;
    }
    return instances.values.toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  @override
  Future<void> startObserving() => platform.startObserving();
  @override
  Future<void> stopObserving() => platform.stopObserving();
}
