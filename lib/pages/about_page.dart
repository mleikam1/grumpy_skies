import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Grumpy Skies'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Grumpy Skies',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'A personality-driven weather app that roasts your forecast '
                  'instead of politely whispering it.',
            ),
            SizedBox(height: 16),
            Text(
              'Data Sources (planned):\n'
                  '- Apple WeatherKit\n'
                  '- AccuWeather (hourly)\n'
                  '- RainViewer (radar)',
            ),
            SizedBox(height: 16),
            Text('Version 0.1.0'),
          ],
        ),
      ),
    );
  }
}
