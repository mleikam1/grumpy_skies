import 'package:flutter/material.dart';

import '../../../design/dm_theme.dart';

/// A bundled legend for the exact product whose provider publishes the bins.
/// No network request is made here. Do not reuse the global palette for the
/// separately documented US forecast endpoint or NOAA's processed RGB tiles.
class RadarColorScale extends StatelessWidget {
  const RadarColorScale({
    super.key,
    required this.source,
    this.compact = true,
    this.onOpenGuide,
  });

  final String source;
  final bool compact;
  final VoidCallback? onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final global = source == 'openweather_global';
    final noaa = source == 'noaa_mrms';
    final label = global || noaa
        ? 'Reflectivity · dBZ'
        : source == 'openweather_futurecast'
            ? 'Precipitation color guide'
            : 'Weather color guide';
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.dmColors.textSecondary,
        );
    final contents = global
        ? Semantics(
            label: 'OpenWeather global radar reflectivity color scale',
            value: '0 to 70 or more dBZ. '
                'Increasing values indicate stronger returned radar echoes.',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) ...[
                    Text(label, style: style),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Text('0', style: style),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: SizedBox(
                          height: 10,
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            child: CustomPaint(painter: _GlobalRadarScale()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('70+ dBZ', style: style),
                    ],
                  ),
                ],
              ),
            ),
          )
        : Text(label, style: style);
    if (onOpenGuide == null) return contents;
    return Semantics(
      button: true,
      label: '$label. Open provider color guide.',
      child: InkWell(
        onTap: onOpenGuide,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: contents),
              const SizedBox(width: 8),
              Icon(Icons.info_outline,
                  size: 18, color: context.dmColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Source: OpenWeather Global Precipitation Maps History & Forecast,
// https://openweathermap.org/api/global-precipitation-map-forecast
// "Default palette ranges", verified 2026-10-18. These are discrete bins;
// interpolating the colors would imply values the provider does not publish.
// The final unbounded 70+ bin is rendered as a small end cap.
const _globalRadarBins = <(double, Color)>[
  (0, Color(0xFF000000)),
  (7.01, Color(0xFF00B2FF)),
  (9.83, Color(0xFF00A7FF)),
  (12.17, Color(0xFF00FA96)),
  (15.91, Color(0xFF00FA64)),
  (20.02, Color(0xFF00E600)),
  (21.96, Color(0xFF00D300)),
  (23.98, Color(0xFF00BA00)),
  (26.01, Color(0xFF00A000)),
  (28, Color(0xFF008C00)),
  (29.99, Color(0xFF007800)),
  (31.01, Color(0xFF006400)),
  (32.01, Color(0xFF005A00)),
  (33, Color(0xFF005000)),
  (34, Color(0xFF004600)),
  (35.01, Color(0xFFEFF800)),
  (36, Color(0xFFF3EB00)),
  (37, Color(0xFFFADC00)),
  (39, Color(0xFFFFCD00)),
  (40, Color(0xFFFF9600)),
  (41, Color(0xFFFF5B00)),
  (42, Color(0xFFFF0000)),
  (45.09, Color(0xFFFF0064)),
  (47.91, Color(0xFFFF0092)),
  (53.01, Color(0xFFAA2BC3)),
  (59.83, Color(0xFF7609A4)),
  (70, Color(0xFF3D015E)),
];

class _GlobalRadarScale extends CustomPainter {
  const _GlobalRadarScale();

  @override
  void paint(Canvas canvas, Size size) {
    final cap = (size.width * .025).clamp(1.0, 6.0);
    final boundedWidth = (size.width - cap).clamp(0.0, double.infinity);
    final paint = Paint();
    for (var i = 0; i < _globalRadarBins.length; i++) {
      final (start, color) = _globalRadarBins[i];
      final left = boundedWidth * start / 70;
      final right = i == _globalRadarBins.length - 1
          ? size.width
          : boundedWidth * _globalRadarBins[i + 1].$1 / 70;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, size.height),
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobalRadarScale oldDelegate) => false;
}
