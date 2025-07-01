import 'package:flutter/material.dart';
import '../components/logo.dart';
import '../components/button.dart';
import 'game_screen.dart';
import '../components/local_storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  Future<void> _checkSavedGame() async {
    final saved = await LocalStorageService.getString('saved_game');
    setState(() {
      _hasSavedGame = saved != null && saved.isNotEmpty && saved != '{}' && saved != 'null';
    });
  }

  void _navigateToGame(BuildContext context, String mode, {bool resume = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(mode: mode, resume: resume),
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
                if (_hasSavedGame) ...[
                  Button(
                    label: 'Continue',
                    icon: Icons.play_arrow,
                    type: ButtonType.filled,
                    color: Colors.black,
                    onPressed: () => _navigateToGame(context, 'story', resume: true),
                  ),
                  const SizedBox(height: 20),
                ],
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
