import 'package:flutter/material.dart';

class RoastBlock extends StatelessWidget {
  final String personaName;
  final String roast;
  final List<_RoastStat> stats;
  final VoidCallback? onRefresh;
  final VoidCallback? onShare;
  final bool coolingDown;

  const RoastBlock({
    super.key,
    required this.personaName,
    required this.roast,
    required this.stats,
    this.onRefresh,
    this.onShare,
    this.coolingDown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2A2A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueGrey[800],
                child: Text(
                  personaName.isNotEmpty ? personaName[0] : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personaName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Forecast Roast',
                      style: TextStyle(
                        color: Colors.blueGrey[200],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: coolingDown ? null : onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh roast',
                  ),
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: 'Share roast',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            roast,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: stats
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 16, color: Colors.blueGrey[200]),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RoastStat {
  final IconData icon;
  final String label;

  const _RoastStat(this.icon, this.label);
}

extension RoastStatBuilder on RoastBlock {
  static List<_RoastStat> buildStats(List<({IconData icon, String label})> items) {
    return items.map((e) => _RoastStat(e.icon, e.label)).toList();
  }
}
