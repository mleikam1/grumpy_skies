import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/utils/radar_time.dart';

void main() {
  test('FutureCast frames start at Now and advance in 10-minute steps', () {
    final frames = generateRadarFrames(
      mode: RadarMode.futureCast,
      now: DateTime.utc(2026, 6, 26, 17, 7, 59),
    );
    final latest = DateTime.utc(2026, 6, 26, 17).millisecondsSinceEpoch ~/ 1000;

    expect(frames, hasLength(37));
    expect(frames.first.timestamp, latest);
    expect(frames.first.label, 'Now');
    expect(frames.first.source, 'openweather_futurecast');
    expect(frames[1].timestamp - frames.first.timestamp, radarStepSeconds);
    expect(frames.last.timestamp - frames.first.timestamp, 6 * 60 * 60);
    expect(frames.last.label, '+6h');
  });
}
