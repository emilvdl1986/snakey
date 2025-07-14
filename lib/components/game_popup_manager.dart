
import 'package:flutter/material.dart';
import 'game_ads.dart';

/// Handles all popups and modals for the game canvas.
/// Usage: Place this widget above your GameCanvas and call showGamePopup(context, ...) as needed.
class GamePopupManager {
  static Future<dynamic> showGameOver({
    required BuildContext context,
    required int score,
    required int livesLeft,
    required int coins,
    required VoidCallback onRespawn,
    required VoidCallback onReset,
    VoidCallback? onRespawnWithCoins,
  }) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your score: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lives left: $livesLeft',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (livesLeft > 0)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onRespawn();
                          },
                          child: const Text('Respawn'),
                        ),
                      if (livesLeft > 0) const SizedBox(height: 12),
                      if (livesLeft == 0 && coins >= 3 && onRespawnWithCoins != null)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onRespawnWithCoins();
                          },
                          child: const Text('Respawn (use 3 coins)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        ),
                      if (livesLeft == 0 && coins >= 3) const SizedBox(height: 12),
                      if (livesLeft == 0 && (coins < 3 || onRespawnWithCoins == null))
                        ElevatedButton(
                          onPressed: () {
                            // Show rewarded ad logic should be handled by parent via callback or state
                            Navigator.of(context).pop('watchAd');
                          },
                          child: const Text('Watch Ad to Continue'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onReset();
                        },
                        child: const Text('Reset'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showLevelComplete({
    required BuildContext context,
    required int pointsGained,
    required int coinsGained,
    required int livesGained,
    required int totalScore,
    required VoidCallback onContinue,
    VoidCallback? onShare,
    bool isFinalStage = false,
    VoidCallback? onBackToHome,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isFinalStage ? 'Game Complete!' : 'Complete!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFinalStage ? 32 : 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isFinalStage)
                        const Text(
                          'Congrats! You have completed the story games.',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                      if (isFinalStage) const SizedBox(height: 16),
                      Text(
                        isFinalStage ? 'Total Score: $totalScore' : 'Points x $pointsGained',
                        style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (!isFinalStage) ...[
                        Text('Coins x $coinsGained', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Lives x $livesGained', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Total Score x $totalScore', style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 32),
                      if (isFinalStage && onBackToHome != null)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onBackToHome();
                          },
                          child: const Text('Back to Home'),
                        ),
                      if (!isFinalStage)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onContinue();
                          },
                          child: const Text('Continue'),
                        ),
                      if (!isFinalStage && onShare != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onShare();
                            },
                            child: const Text('Share with Friends'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
