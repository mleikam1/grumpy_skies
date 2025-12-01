import 'package:flutter/material.dart';

class PersonaRoastBubble extends StatelessWidget {
  final String personaName;
  final String roast;

  const PersonaRoastBubble({
    super.key,
    required this.personaName,
    required this.roast,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(personaName[0]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personaName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(roast),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
