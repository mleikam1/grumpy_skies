import 'package:flutter/material.dart';

import '../models/roast.dart';

class RoastRevealFog extends StatefulWidget {
  final Roast roast;

  const RoastRevealFog({
    super.key,
    required this.roast,
  });

  @override
  State<RoastRevealFog> createState() => _RoastRevealFogState();
}

class _RoastRevealFogState extends State<RoastRevealFog> {
  bool _revealed = false;

  void _toggleReveal() {
    setState(() {
      _revealed = !_revealed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleReveal,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Stack(
          children: [
            Text(
              widget.roast.text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!_revealed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap to clear the fog',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
