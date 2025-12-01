import 'package:flutter/material.dart';

class MemeGeneratorPage extends StatefulWidget {
  const MemeGeneratorPage({super.key});

  @override
  State<MemeGeneratorPage> createState() => _MemeGeneratorPageState();
}

class _MemeGeneratorPageState extends State<MemeGeneratorPage> {
  String _topText = '';
  String _bottomText = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meme Generator'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.grey.shade300,
              child: Stack(
                children: [
                  // TODO: Background weather image
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _topText.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _bottomText.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Top text',
              ),
              onChanged: (v) => setState(() => _topText = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Bottom text',
              ),
              onChanged: (v) => setState(() => _bottomText = v),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: capture widget as image + share
              },
              icon: const Icon(Icons.share),
              label: const Text('Export / Share'),
            ),
          ),
        ],
      ),
    );
  }
}
