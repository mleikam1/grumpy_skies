import 'package:flutter/material.dart';

import '../config/app_routes.dart';

class RadarPage extends StatelessWidget {
  const RadarPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: integrate RainViewer tiles via a map widget
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar'),
      ),
      body: const Center(
        child: Text('Radar view placeholder'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, AppRoutes.home);
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacementNamed(context, AppRoutes.burns);
              break;
            case 3:
              Navigator.pushReplacementNamed(context, AppRoutes.settings);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.whatshot), label: 'Burns'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
