import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Google's Official Test Ad Unit IDs
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testAppOpenAdUnitIdAndroid = 'ca-app-pub-3940256099942544/3419835294';
  static const String _testAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  // Production Ad Unit IDs (thay thế bằng Ad Unit IDs thật khi publish)
  static const String _prodBannerAdUnitIdAndroid = 'ca-app-pub-2189112136936277/3489158520';
  static const String _prodBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _prodInterstitialAdUnitIdAndroid = 'ca-app-pub-2189112136936277/9862995184';
  static const String _prodInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _prodAppOpenAdUnitIdAndroid = 'ca-app-pub-2189112136936277/8760106002';
  static const String _prodAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';
  static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-2189112136936277/2424979553'; // TODO: Replace with real ID
  static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313'; // TODO: Replace with real ID

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  RewardedAd? _rewardedAd;
  
  // Thời gian lần cuối hiển thị App Open Ad (để tránh spam)
  DateTime? _lastAppOpenAdTime;
  static const Duration _appOpenAdCooldown = Duration(hours: 4); // 4 giờ mới hiển thị lại

  // Helper methods để lấy đúng Ad Unit ID dựa trên debug mode
  String _getBannerAdUnitId() {
    if (kDebugMode) {
      print('🔧 DEBUG MODE: Using TEST Banner Ad Unit ID');
      return Platform.isAndroid ? _testBannerAdUnitIdAndroid : _testBannerAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION Banner Ad Unit ID');
      return Platform.isAndroid ? _prodBannerAdUnitIdAndroid : _prodBannerAdUnitIdIOS;
    }
  }

  String _getInterstitialAdUnitId() {
    if (kDebugMode) {
      print('🔧 DEBUG MODE: Using TEST Interstitial Ad Unit ID');
      return Platform.isAndroid ? _testInterstitialAdUnitIdAndroid : _testInterstitialAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION Interstitial Ad Unit ID');
      return Platform.isAndroid ? _prodInterstitialAdUnitIdAndroid : _prodInterstitialAdUnitIdIOS;
    }
  }

  String _getAppOpenAdUnitId() {
    if (kDebugMode) {
      print('🔧 DEBUG MODE: Using TEST App Open Ad Unit ID');
      return Platform.isAndroid ? _testAppOpenAdUnitIdAndroid : _testAppOpenAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION App Open Ad Unit ID');
      return Platform.isAndroid ? _prodAppOpenAdUnitIdAndroid : _prodAppOpenAdUnitIdIOS;
    }
  }

  String _getRewardedAdUnitId() {
    if (kDebugMode) {
      print('🔧 DEBUG MODE: Using TEST Rewarded Ad Unit ID');
      return Platform.isAndroid ? _testRewardedAdUnitIdAndroid : _testRewardedAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION Rewarded Ad Unit ID');
      return Platform.isAndroid ? _prodRewardedAdUnitIdAndroid : _prodRewardedAdUnitIdIOS;
    }
  }

  // Khởi tạo AdMob (chỉ trên mobile)
  static Future<void> initialize() async {
    if (kIsWeb) {
      print('AdMob không được hỗ trợ trên web');
      return;
    }
    
    // MobileAds đã được khởi tạo trong main.dart, không cần khởi tạo lại
    print('AdMob service initialized (MobileAds already initialized in main.dart)');
  }

  // Tạo Banner Ad
  BannerAd createBannerAd() {
    if (kIsWeb) {
      throw UnsupportedError('Banner ads không được hỗ trợ trên web');
    }
    final adUnitId = _getBannerAdUnitId();
    
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('Banner ad opened');
        },
        onAdClosed: (ad) {
          print('Banner ad closed');
        },
      ),
    );
  }

  // Tạo Interstitial Ad
  void createInterstitialAd() {
    if (kIsWeb) {
      print('Interstitial ads không được hỗ trợ trên web');
      return;
    }
    final adUnitId = _getInterstitialAdUnitId();
    
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          print('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// [onDismissedOrUnavailable] gọi sau khi ad đóng, lỗi hiển thị, hoặc không có ad sẵn (để điều hướng sau quảng cáo).
  void showInterstitialAd({VoidCallback? onDismissedOrUnavailable}) {
    if (kIsWeb) {
      onDismissedOrUnavailable?.call();
      return;
    }
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('Interstitial ad showed full screen content');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('Interstitial ad dismissed');
          ad.dispose();
          _interstitialAd = null;
          onDismissedOrUnavailable?.call();
          createInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Interstitial ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
          onDismissedOrUnavailable?.call();
        },
      );
      _interstitialAd!.show();
    } else {
      print('Interstitial ad not ready');
      onDismissedOrUnavailable?.call();
    }
  }

  // Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // Dispose interstitial ad
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  // Tạo App Open Ad
  void createAppOpenAd() {
    if (kIsWeb) {
      print('App Open ads không được hỗ trợ trên web');
      return;
    }
    final adUnitId = _getAppOpenAdUnitId();
    
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          print('App Open ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('App Open ad failed to load: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  // Hiển thị App Open Ad (với cooldown)
  void showAppOpenAdIfReady() {
    // Kiểm tra cooldown
    if (_lastAppOpenAdTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAppOpenAdTime!);
      if (timeSinceLastAd < _appOpenAdCooldown) {
        print('App Open ad in cooldown, remaining: ${_appOpenAdCooldown - timeSinceLastAd}');
        return;
      }
    }

    if (_appOpenAd != null) {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('App Open ad showed full screen content');
          _lastAppOpenAdTime = DateTime.now();
        },
        onAdDismissedFullScreenContent: (ad) {
          print('App Open ad dismissed');
          ad.dispose();
          _appOpenAd = null;
          // Tạo ad mới cho lần tiếp theo
          createAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('App Open ad failed to show: $error');
          ad.dispose();
          _appOpenAd = null;
        },
      );
      _appOpenAd!.show();
    } else {
      print('App Open ad not ready');
    }
  }

  // Kiểm tra xem có thể hiển thị App Open Ad không
  bool canShowAppOpenAd() {
    if (_lastAppOpenAdTime == null) return true;
    final timeSinceLastAd = DateTime.now().difference(_lastAppOpenAdTime!);
    return timeSinceLastAd >= _appOpenAdCooldown;
  }

  // Dispose App Open ad
  void disposeAppOpenAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }

  // Tạo Rewarded Ad
  void createRewardedAd() {
    if (kIsWeb) {
      print('Rewarded ads không được hỗ trợ trên web');
      return;
    }
    final adUnitId = _getRewardedAdUnitId();
    
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          print('Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  // Hiển thị Rewarded Ad với callback
  void showRewardedAd({
    required Function() onRewarded,
    Function(String)? onAdFailedToShow,
  }) {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('Rewarded ad showed full screen content');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('Rewarded ad dismissed');
          ad.dispose();
          _rewardedAd = null;
          // Tạo ad mới cho lần tiếp theo
          createRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Rewarded ad failed to show: $error');
          ad.dispose();
          _rewardedAd = null;
          if (onAdFailedToShow != null) {
            onAdFailedToShow(error.message);
          }
          // Tạo ad mới cho lần tiếp theo
          createRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          print('User earned reward: ${reward.amount} ${reward.type}');
          onRewarded();
        },
      );
    } else {
      print('Rewarded ad not ready');
      if (onAdFailedToShow != null) {
        onAdFailedToShow('Rewarded ad not ready');
      }
      // Try to load a new ad
      createRewardedAd();
    }
  }

  // Kiểm tra xem Rewarded Ad có sẵn không
  bool isRewardedAdReady() {
    return _rewardedAd != null;
  }

  // Dispose Rewarded ad
  void disposeRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  // Dispose tất cả ads
  void disposeAll() {
    disposeBannerAd();
    disposeInterstitialAd();
    disposeAppOpenAd();
    disposeRewardedAd();
  }
}
