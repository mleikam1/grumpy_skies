import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/radar/radar_presentation.dart';
import 'package:grumpy_skies/models/weather_models.dart';

RadarFrame observation(DateTime instant, {bool renderable = true}) =>
    RadarFrame(
      timestamp: instant.millisecondsSinceEpoch ~/ 1000,
      label: 'Provider label is not a clock',
      type: RadarFrameType.history,
      isLatest: false,
      renderable: renderable,
    );

void main() {
  test('latest means newest available observation in the selected place zone',
      () {
    final older = observation(DateTime.utc(2026, 10, 18, 12, 31));
    final newest = observation(DateTime.utc(2026, 10, 18, 12, 45));
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: [older, newest],
      frame: newest,
      now: DateTime.utc(2026, 10, 18, 12, 47),
      timezone: 'America/Chicago',
      timezoneOffset: 0,
    );
    expect(display.title, 'Latest · 7:45 AM');
    expect(display.subtitle, 'Observed 2 min ago');
    expect(display.isLatestObserved, isTrue);
    expect(display.refreshLabel, isNull);
    expect(display.frameTimeLabel, 'Sun, Oct 18, 2026 · 7:45 AM · UTC−05:00');
    expect(display.timelineValue, contains('Latest observation'));
  });

  test('a fresh download never makes an old observation fresh', () {
    final older = observation(DateTime.utc(2026, 10, 18, 12, 10));
    final newest = observation(DateTime.utc(2026, 10, 18, 12, 45));
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: [older, newest],
      frame: older,
      now: DateTime.utc(2026, 10, 18, 12, 47),
      timezone: 'America/Chicago',
      refreshedAt: DateTime.utc(2026, 10, 18, 12, 47),
    );
    expect(display.title, 'Observed · 7:10 AM');
    expect(display.subtitle, 'Observed 37 min ago');
    expect(display.refreshLabel, 'Metadata refreshed just now');
    expect(display.refreshedTimeLabel, contains('7:47 AM'));
    expect(display.isLatestObserved, isFalse);
  });

  test('history across local midnight includes the calendar day', () {
    final frame = observation(DateTime.utc(2026, 10, 19, 4, 55));
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: [frame],
      frame: frame,
      now: DateTime.utc(2026, 10, 19, 5, 5),
      timezone: 'America/Chicago',
    );
    expect(display.title, 'Latest · Sun, Oct 18 · 11:55 PM');
    expect(display.subtitle, 'Observed 10 min ago');
  });

  test('future dates, repeated DST hours and details preserve actual instants',
      () {
    final daylight = observation(DateTime.utc(2026, 11, 1, 6, 30));
    final standard = observation(DateTime.utc(2026, 11, 1, 7, 30));
    RadarPresentation at(RadarFrame frame) => RadarPresentation(
          mode: RadarMode.futureCast,
          frames: [daylight, standard],
          frame: frame,
          now: DateTime.utc(2026, 11, 1, 4, 50),
          timezone: 'America/Chicago',
        );
    expect(at(daylight).title, 'Sun, Nov 1 · 1:30 AM UTC−05:00');
    expect(at(standard).title, 'Sun, Nov 1 · 1:30 AM UTC−06:00');
    expect(at(standard).subtitle, 'Forecast precipitation');
    expect(at(standard).isLatestObserved, isFalse);
    expect(at(standard).forecastIssueTimeLabel,
        'Not provided by this radar source');
    expect(at(standard).timelineTicks.map((tick) => tick.label),
        ['1:30 AM UTC−05:00', '1:30 AM UTC−06:00']);
  });

  test('spring DST skips the missing local hour', () {
    final before = observation(DateTime.utc(2026, 3, 8, 7, 30));
    final after = observation(DateTime.utc(2026, 3, 8, 8, 30));
    final display = RadarPresentation(
      mode: RadarMode.futureCast,
      frames: [before, after],
      frame: after,
      now: DateTime.utc(2026, 3, 8, 7),
      timezone: 'America/Chicago',
    );
    expect(display.title, 'Today · 3:30 AM');
    expect(display.timelineTicks.map((tick) => tick.label),
        ['1:30 AM', '3:30 AM']);
  });

  test('irregular frames in both repeated hours still identify their offsets',
      () {
    final before = observation(DateTime.utc(2026, 11, 1, 6, 10));
    final after = observation(DateTime.utc(2026, 11, 1, 7, 40));
    final display = RadarPresentation(
      mode: RadarMode.futureCast,
      frames: [before, after],
      frame: after,
      now: DateTime.utc(2026, 11, 1, 6),
      timezone: 'America/Chicago',
    );
    expect(display.title, 'Today · 1:40 AM UTC−06:00');
    expect(display.timelineTicks.map((tick) => tick.label),
        ['1:10 AM UTC−05:00', '1:40 AM UTC−06:00']);
  });

  test(
      'unknown timezone is explicitly UTC and a fixed offset cannot forecast DST',
      () {
    final frame = observation(DateTime.utc(2026, 11, 1, 7, 30));
    final display = RadarPresentation(
      mode: RadarMode.futureCast,
      frames: [frame],
      frame: frame,
      now: DateTime.utc(2026, 11, 1, 7),
      timezone: 'Unknown/Place',
      timezoneOffset: -18000,
    );
    expect(display.title, 'Today · 7:30 AM UTC');
    expect(display.usesUtcFallback, isTrue);
    expect(display.frameTimeLabel, contains('UTC+00:00'));
  });

  test('ticks and scrub snapping honor irregular available metadata', () {
    final start = DateTime.utc(2026, 10, 18, 12);
    final frames = [
      observation(start),
      observation(start.add(const Duration(minutes: 4))),
      observation(start.add(const Duration(minutes: 27))),
      observation(start.add(const Duration(minutes: 30)), renderable: false),
      observation(start.add(const Duration(minutes: 60))),
    ];
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: frames,
      frame: frames[2],
      now: start.add(const Duration(minutes: 61)),
      timezone: 'America/Chicago',
    );
    expect(display.timelineTicks.map((tick) => tick.index), [0, 2, 4]);
    expect(display.timelineTicks.map((tick) => tick.fraction), [0, .45, 1]);
    expect(display.timelineTicks.map((tick) => tick.label),
        ['7 AM', '7:27 AM', '8 AM']);
    expect(display.nearestFrameIndex(.5), 2);
    expect(display.nearestFrameIndex(.06), 1);
    expect(display.nearestFrameIndex(-1), 0);
    expect(display.nearestFrameIndex(2), 4);
    expect(display.fractionForFrame(frames[2]), .45);
  });

  test('ticks crossing midnight use their real calendar dates', () {
    final first = observation(DateTime.utc(2026, 10, 19, 4, 40));
    final last = observation(DateTime.utc(2026, 10, 19, 5, 20));
    final display = RadarPresentation(
      mode: RadarMode.futureCast,
      frames: [last, first],
      frame: last,
      now: DateTime.utc(2026, 10, 19, 4, 35),
      timezone: 'America/Chicago',
    );
    expect(display.title, 'Mon, Oct 19 · 12:20 AM');
    expect(display.timelineTicks.map((tick) => tick.index), [1, 0]);
    expect(display.timelineTicks.map((tick) => tick.label),
        ['10/18 · 11:40 PM', '10/19 · 12:20 AM']);
  });

  test('empty metadata never invents a current frame or update time', () {
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: const [],
      frame: null,
      now: DateTime.utc(2026, 10, 18),
    );
    expect(display.title, 'Radar unavailable');
    expect(display.subtitle, 'No observed frames available');
    expect(display.frameTimeLabel, 'No frame selected');
    expect(display.timelineTicks, isEmpty);
    expect(display.nearestFrameIndex(.5), isNull);
    expect(display.refreshLabel, isNull);
    expect(display.isLatestObserved, isFalse);
  });

  test(
      'details retain provider seconds rather than rounding the frame identity',
      () {
    final frame = observation(DateTime.utc(2026, 10, 18, 12, 45, 37));
    final display = RadarPresentation(
      mode: RadarMode.usForecast,
      frames: [frame],
      frame: frame,
      now: DateTime.utc(2026, 10, 18, 12, 47),
      timezone: 'America/Chicago',
    );
    expect(display.frameTimeLabel, contains('7:45:37 AM'));
    expect(display.timelineTicks.single.timestamp, frame.timestamp);
  });
}
