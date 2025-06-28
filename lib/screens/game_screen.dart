import 'package:flutter/material.dart';
import '../components/game_app_bar.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class GameScreen extends StatefulWidget {
  final String mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Map<String, dynamic>? data;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadGameType();
  }

  Future<void> _loadGameType() async {
    try {
      final String jsonString = await rootBundle.loadString('${widget.mode}.json');
      setState(() {
        data = json.decode(jsonString);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Could not load ${widget.mode}.json';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarSettings = data?['appBarSettings'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: GameAppBar(
        title: data?['title'] ?? 'Game Screen ${widget.mode}',
        showScore: appBarSettings?['showScore'] ?? false,
        showLives: appBarSettings?['showLives'] ?? false,
        showCoins: appBarSettings?['showCoins'] ?? false,
        showLevel: appBarSettings?['showLevel'] ?? false,
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : error != null
                ? Text(error!, style: const TextStyle(color: Colors.red))
                : Text(
                    'Loaded: ${widget.mode}.json\n'
                    'Title: ${data?['title']}\n',
                    style: const TextStyle(fontSize: 24),
                  ),
      ),
    );
  }
}
