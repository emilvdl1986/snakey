import 'package:flutter/material.dart';
import '../components/game_app_bar.dart';
import '../components/game_canvas.dart';
import '../components/local_storage_service.dart';
import '../components/swipe_controller.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';

class GameScreen extends StatefulWidget {
  final String mode;
  final bool resume;
  const GameScreen({super.key, required this.mode, this.resume = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GlobalKey<GameCanvasState> gameCanvasKey = GlobalKey<GameCanvasState>();
  final ScreenshotController screenshotController = ScreenshotController();

  void _sendSwipeDirection(String direction) {
    SwipeDirectionNotification(direction).dispatch(context);
  }
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

      // Load the original grid settings from asset file, and also set data/storyData for app bar
      Map<String, dynamic> loadedGridSettings = {};
      List<dynamic>? loadedObjects;
      Map<String, dynamic>? loadedData;
      Map<String, dynamic>? loadedStory;
      if (savedMode == 'endless') {
        final String jsonString = await rootBundle.loadString('assets/endless.json');
        loadedData = json.decode(jsonString);
        if (loadedData != null && loadedData['gridSettings'] != null) {
          loadedGridSettings = loadedData['gridSettings'] as Map<String, dynamic>;
        } else {
          loadedGridSettings = {};
        }
        final String objectsJson = await rootBundle.loadString('assets/objects/endless_objects.json');
        loadedObjects = json.decode(objectsJson) as List<dynamic>;
      } else if (savedMode == 'story') {
        final String storyJson = await rootBundle.loadString('assets/story.json');
        loadedStory = json.decode(storyJson);
        final String stageJson = await rootBundle.loadString('assets/stages/${savedGame['level'] ?? 1}.json');
        final Map<String, dynamic> loadedStage = json.decode(stageJson);
        if (loadedStage != null && loadedStage['gridSettings'] != null) {
          loadedGridSettings = loadedStage['gridSettings'] as Map<String, dynamic>;
        } else {
          loadedGridSettings = {};
        }
        final String objectsJson = await rootBundle.loadString('assets/objects/story_objects.json');
        loadedObjects = json.decode(objectsJson) as List<dynamic>;
        // If this is the final stage, set isFinalStage to true so the popup appears after resume
        if (loadedStage['gridSettings'] != null && loadedStage['gridSettings']['end'] == true) {
          isFinalStage = true;
        }
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
        isFinalStage = isFinalStage; // will be true if final stage, else false
        // Set data and storyData for app bar
        if (savedMode == 'endless' && loadedData != null) {
          data = loadedData;
        } else if (savedMode == 'story' && loadedStory != null) {
          data = loadedStory;
          storyData = loadedStory;
        }
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
      // Check if the next stage file exists before updating level
      setState(() {
        isLoading = true;
      });
      try {
        final String stagePath = 'assets/stages/$newLevel.json';
        // Try to load the file, if it fails, do not update level
        final String stageJson = await rootBundle.loadString(stagePath);
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
          error = null;
        });
      } catch (e) {
        // If file does not exist, do not update currentLevel, show a message or end the game
        setState(() {
          error = 'No more levels! You have completed all available stages.';
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
        currentLevel: currentLevel,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
              : (gridSettings != null
                  ? Container(
                      color: Colors.black,
                      child: NotificationListener<SwipeDirectionNotification>(
                        onNotification: (notification) {
                          debugPrint('NotificationListener received swipe: ' + notification.direction);
                          final state = gameCanvasKey.currentState;
                          if (state != null && state.mounted) {
                            state.setDirectionFromSwipe(notification.direction);
                          }
                          return true;
                        },
                        child: Screenshot(
                          controller: screenshotController,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: GameCanvas(
                                  key: gameCanvasKey,
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
                                  screenshotController: screenshotController, // pass down
                                ),
                              ),
                              Builder(
                                builder: (notificationContext) => SwipeController(notificationContext: notificationContext),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Center(child: Text('Grid settings not found'))),
    );
  }
}


