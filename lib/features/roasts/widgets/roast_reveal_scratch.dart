import 'package:flutter/material.dart';

import '../models/roast.dart';

class RoastRevealScratch extends StatefulWidget {
  final Roast roast;
  final VoidCallback? onRevealed;

  const RoastRevealScratch({
    super.key,
    required this.roast,
    this.onRevealed,
  });

  @override
  State<RoastRevealScratch> createState() => _RoastRevealScratchState();
}

class _RoastRevealScratchState extends State<RoastRevealScratch> {
  bool _revealed = false;

  void _reveal() {
    if (!_revealed) {
      widget.onRevealed?.call();
    }
    setState(() {
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reveal,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _revealed ? Colors.white : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Center(
          child: Text(
            _revealed ? widget.roast.text : 'Scratch to reveal',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
