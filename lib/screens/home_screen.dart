import 'package:flutter/material.dart';
import '../components/logo.dart';
import '../components/button.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _navigateToGame(BuildContext context, String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Logo(size: 300),
                const SizedBox(height: 40),
                Button(
                  label: 'Play Story',
                  icon: Icons.play_arrow,
                  type: ButtonType.outlined,
                  onPressed: () => _navigateToGame(context, 'story'),
                ),
                const SizedBox(height: 20),
                Button(
                  label: 'Endless Snake',
                  icon: Icons.play_arrow,
                  type: ButtonType.outlined,
                  onPressed: () => _navigateToGame(context, 'endless'),
                ),
                const SizedBox(height: 20),
                Button(
                  label: 'Top Scores',
                  icon: Icons.leaderboard,
                  type: ButtonType.filled,
                  onPressed: () {
                    Navigator.pushNamed(context, '/top-scores');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
