import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import '../components/logo.dart';
import '../components/button.dart';
import 'game_screen.dart';
import '../components/local_storage_service.dart';
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen
    setState(() {});
  }
  // _hasSavedGame and _checkSavedGame removed; use FutureBuilder in build

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
                FutureBuilder<String?>(
                  key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                  future: LocalStorageService.getString('saved_game'),
                  builder: (context, snapshot) {
                    final saved = snapshot.data;
                    final hasSavedGame = saved != null && saved.isNotEmpty && saved != '{}' && saved != 'null';
                    if (!hasSavedGame) return const SizedBox.shrink();
                    String mode = 'story';
                    try {
                      final dynamic decoded = saved.isNotEmpty ? jsonDecode(saved) : null;
                      if (decoded != null && decoded is Map && decoded['gameMode'] != null) {
                        mode = decoded['gameMode'];
                      }
                    } catch (_) {}
                    return Column(
                      children: [
                        Button(
                          label: 'Continue',
                          icon: Icons.play_arrow,
                          type: ButtonType.filled,
                          color: Colors.black,
                          onPressed: () => _navigateToGame(context, mode, resume: true),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
                /*Button(
                  label: 'Play Story',
                  icon: Icons.play_arrow,
                  type: ButtonType.outlined,
                  onPressed: () => _navigateToGame(context, 'story'),
                ),
                const SizedBox(height: 20),*/
                Button(
                  label: 'Play',
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
