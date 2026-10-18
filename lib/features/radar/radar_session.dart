import '../../models/weather_models.dart';
import '../../services/open_weather_backend_client.dart';
import 'radar_playback_controller.dart';

/// Retains the user's timeline across primary tabs without retaining a hidden
/// map or starting work before Radar is visited. The app shell owns this object;
/// visible RadarScreen instances only borrow its single controller.
class RadarSession {
  RadarPlaybackController? _controller;

  RadarPlaybackController? get controller => _controller;

  RadarPlaybackController obtain({
    required OpenWeatherBackendClient client,
    required LocationCandidate location,
    DateTime Function()? now,
  }) =>
      _controller ??=
          RadarPlaybackController(client: client, location: location, now: now);

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
