import 'package:flutter/material.dart';

class WhatWeatherSaysCard extends StatelessWidget {
  const WhatWeatherSaysCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What the weather says',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text("Your weather says you're about 67% chaos today."),
            ],
          ),
        ),
      ),
    );
  }
}
