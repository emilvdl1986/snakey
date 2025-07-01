import 'package:flutter/material.dart';
import '../components/game_app_bar.dart';
import '../components/game_canvas.dart';
import '../components/local_storage_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class GameScreen extends StatefulWidget {
  final String mode;
  final bool resume;
  const GameScreen({super.key, required this.mode, this.resume = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? gridSettings;
  Map<String, dynamic>? storyData;
  Map<String, dynamic>? resumeState;
  List<dynamic>? objectDefinitions;
  bool isLoading = true;
  String? error;
  int stage = 1;
  int score = 0;
  int livesLeft = 3;
  int coins = 0;
  int currentLevel = 1; // LIFTED STATE
  bool isFinalStage = false;
  String? _resumeMode; // Track mode from saved game if resuming

  @override
  void initState() {
    super.initState();
    if (widget.resume) {
      _loadResumeGame();
    } else {
      _loadGameType();
    }
  }

  Future<void> _loadResumeGame() async {
    try {
      final saved = await LocalStorageService.getString('saved_game');
      if (saved == null || saved.isEmpty || saved == '{}' || saved == 'null') {
        setState(() {
          error = 'No saved game found.';
          isLoading = false;
        });
        return;
      }
      // Accept both Map<String, dynamic> and LinkedMap (from json.decode)
      final dynamic decoded = json.decode(saved);
      final Map<String, dynamic> savedGame = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded);

      // Use the mode from the saved game if present
      final String savedMode = savedGame['gameMode'] ?? widget.mode;
      _resumeMode = savedMode;

      // Load the original grid settings from asset file
      Map<String, dynamic> loadedGridSettings = {};
      List<dynamic>? loadedObjects;
      if (savedMode == 'endless') {
        final String jsonString = await rootBundle.loadString('assets/endless.json');
        final Map<String, dynamic> loadedData = json.decode(jsonString);
        loadedGridSettings = loadedData['gridSettings'] as Map<String, dynamic>;
        // Load endless objects
        final String objectsJson = await rootBundle.loadString('assets/objects/endless_objects.json');
        loadedObjects = json.decode(objectsJson) as List<dynamic>;
      } else if (savedMode == 'story') {
        final String stageJson = await rootBundle.loadString('assets/stages/${savedGame['level'] ?? 1}.json');
        final Map<String, dynamic> loadedStage = json.decode(stageJson);
        loadedGridSettings = loadedStage['gridSettings'] as Map<String, dynamic>;
        // Load story objects
        final String objectsJson = await rootBundle.loadString('assets/objects/story_objects.json');
        loadedObjects = json.decode(objectsJson) as List<dynamic>;
      }

      setState(() {
        resumeState = savedGame;
        gridSettings = loadedGridSettings;
        objectDefinitions = loadedObjects;
        score = savedGame['score'] ?? 0;
        livesLeft = savedGame['lives'] ?? 3;
        coins = savedGame['coins'] ?? 0;
        currentLevel = savedGame['level'] ?? 1;
        isLoading = false;
        isFinalStage = false;
      });
    } catch (e) {
      setState(() {
        error = 'Could not load saved game.';
        isLoading = false;
      });
    }
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
          isFinalStage = false;
        });
      } else if (widget.mode == 'story') {
        // Load story.json for title and appBarSettings
        final String storyJson = await rootBundle.loadString('assets/story.json');
        final Map<String, dynamic> loadedStory = json.decode(storyJson);
        // Load stage json for gridSettings
        final String stageJson = await rootBundle.loadString('assets/stages/$currentLevel.json');
        final Map<String, dynamic> loadedStage = json.decode(stageJson);
        bool finalStage = false;
        if (loadedStage['gridSettings'] != null && loadedStage['gridSettings']['end'] == true) {
          finalStage = true;
        }
        setState(() {
          storyData = loadedStory;
          data = loadedStory;
          gridSettings = loadedStage['gridSettings'] as Map<String, dynamic>?;
          isLoading = false;
          isFinalStage = finalStage;
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
        bool finalStage = false;
        if (loadedStage['gridSettings'] != null && loadedStage['gridSettings']['end'] == true) {
          finalStage = true;
        }
        setState(() {
          currentLevel = newLevel;
          gridSettings = loadedStage['gridSettings'] as Map<String, dynamic>?;
          isLoading = false;
          isFinalStage = finalStage;
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
                        gridItemOptions: gridSettings!['gridItemOptions'] is Map<String, dynamic>
                            ? gridSettings!['gridItemOptions'] as Map<String, dynamic>
                            : gridSettings!['gridItemOptions'] != null
                                ? Map<String, dynamic>.from(gridSettings!['gridItemOptions'])
                                : null,
                        mode: widget.resume && _resumeMode != null ? _resumeMode! : widget.mode,
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
                        isFinalStage: isFinalStage,
                        resumeState: resumeState,
                        objectDefinitions: objectDefinitions,
                      ),
                    )
                  : const Center(child: Text('Grid settings not found'))),
    );
  }
}
