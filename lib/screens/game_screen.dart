import 'package:flutter/material.dart';
import '../components/game_app_bar.dart';

class GameScreen extends StatelessWidget {
  final String mode;
  const GameScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GameAppBar(title: 'Game Screen $mode'),
      body: Center(
        child: Text(
          'Game Mode: $mode',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
