import 'package:flutter/widgets.dart';

/// Changes shell chrome without replacing or reparenting the radar map.
class RadarExpansionNotification extends Notification {
  const RadarExpansionNotification(this.expanded);
  final bool expanded;
}
