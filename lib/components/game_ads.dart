import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

/// Centralized AdMob ad management for the game.
class GameAdsManager {
  static final GameAdsManager _instance = GameAdsManager._internal();
  factory GameAdsManager() => _instance;
  GameAdsManager._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  void initialize() {
    MobileAds.instance.initialize();
  }

  /// Loads a rewarded ad. Uses the official AdMob test ad unit ID if none is provided.
  /// Android: ca-app-pub-3940256099942544/5224354917
  /// iOS:    ca-app-pub-3940256099942544/1712485313
  void loadRewardedAd({
    String? adUnitId,
    VoidCallback? onLoaded,
    Function(LoadAdError)? onFailed,
    BuildContext? context,
  }) {
    // Use the test ad unit ID if none is provided
    final String testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
    debugPrint('Calling RewardedAd.load with adUnitId: $testAdUnitId');
    RewardedAd.load(
      adUnitId: testAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('RewardedAd loaded successfully');
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ad failed to load:\nCode: ${error.code}\nMessage: ${error.message}');
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          onFailed?.call(error);
        },
      ),
    );
  }

  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  void showRewardedAd({required VoidCallback onRewarded, VoidCallback? onClosed, VoidCallback? onFailed}) {
    if (_rewardedAd == null) {
      onFailed?.call();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        onFailed?.call();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onRewarded();
    });
  }
}
