import 'package:flutter/material.dart';
import '../components/game_app_bar.dart';
import '../components/game_canvas.dart';
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
  Map<String, dynamic>? gridSettings;
  Map<String, dynamic>? storyData;
  bool isLoading = true;
  String? error;
  int stage = 1;
  int score = 0;
  int livesLeft = 3;
  int coins = 0;
  int currentLevel = 1; // LIFTED STATE

  @override
  void initState() {
    super.initState();
    _loadGameType();
  }

  Future<void> _loadGameType() async {
    try {
      if (widget.mode == 'endless') {
        final String jsonString = await rootBundle.loadString('assets/${widget.mode}.json');
        final Map<String, dynamic> loadedData = json.decode(jsonString);
        setState(() {
          data = loadedData;
          gridSettings = loadedData['gridSettings'] as Map<String, dynamic>?;
          isLoading = false;
        });
      } else if (widget.mode == 'story') {
        // Load story.json for title and appBarSettings
        final String storyJson = await rootBundle.loadString('assets/story.json');
        final Map<String, dynamic> loadedStory = json.decode(storyJson);
        // Load stage json for gridSettings
        final String stageJson = await rootBundle.loadString('assets/stages/$currentLevel.json');
        final Map<String, dynamic> loadedStage = json.decode(stageJson);
        setState(() {
          storyData = loadedStory;
          data = loadedStory;
          gridSettings = loadedStage['gridSettings'] as Map<String, dynamic>?;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Could not load grid settings for mode: ${widget.mode}';
        isLoading = false;
      });
    }
  }

  void _handleLevelChanged(int newLevel) async {
    if (widget.mode == 'story') {
      // Reload stage file for new level
      setState(() {
        isLoading = true;
      });
      try {
        final String stageJson = await rootBundle.loadString('assets/stages/$newLevel.json');
        final Map<String, dynamic> loadedStage = json.decode(stageJson);
        setState(() {
          currentLevel = newLevel;
          gridSettings = loadedStage['gridSettings'] as Map<String, dynamic>?;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          error = 'Could not load grid settings for level $newLevel';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        currentLevel = newLevel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarSettings = data?['appBarSettings'] as Map<String, dynamic>?;
    final title = data?['title'] ?? 'Game Screen \\${widget.mode}';
    return Scaffold(
      appBar: GameAppBar(
        title: title,
        showScore: appBarSettings?['showScore'] ?? false,
        showLives: appBarSettings?['showLives'] ?? false,
        showCoins: appBarSettings?['showCoins'] ?? false,
        showLevel: appBarSettings?['showLevel'] ?? false,
        score: score,
        livesLeft: livesLeft,
        coins: coins,
        currentLevel: currentLevel, // FIXED: was 'level:'
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : (gridSettings != null
                  ? Container(
                      color: Colors.black,
                      child: GameCanvas(
                        key: ValueKey(currentLevel), // Force full rebuild on level change
                        columns: gridSettings!['columns'] ?? 0,
                        rows: gridSettings!['rows'] ?? 0,
                        backgroundColor: gridSettings!['backgroundColor'],
                        backgroundImage: gridSettings!['backgroundImage'] ?? false,
                        gridItemOptions: gridSettings!['gridItemOptions'] as Map<String, dynamic>?,
                        mode: widget.mode,
                        onScoreChanged: (newScore) {
                          setState(() {
                            score = newScore;
                          });
                        },
                        onLivesChanged: (newLives) {
                          setState(() {
                            livesLeft = newLives;
                          });
                        },
                        onCoinsChanged: (newCoins) {
                          setState(() {
                            coins = newCoins;
                          });
                        },
                        currentLevel: currentLevel,
                        onLevelChanged: _handleLevelChanged,
                      ),
                    )
                  : const Center(child: Text('Grid settings not found'))),
    );
  }
}
