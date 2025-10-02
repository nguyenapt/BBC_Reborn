import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Test Ad Unit IDs (thay thế bằng Ad Unit IDs thật khi publish)
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-2189112136936277/3790180625';
  static const String _bannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _interstitialAdUnitIdAndroid = 'ca-app-pub-2189112136936277/9972445596';
  static const String _interstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _appOpenAdUnitIdAndroid = 'ca-app-pub-2189112136936277/4437828135'; // Thay bằng App Open Ad Unit ID thật
  static const String _appOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  
  // Thời gian lần cuối hiển thị App Open Ad (để tránh spam)
  DateTime? _lastAppOpenAdTime;
  static const Duration _appOpenAdCooldown = Duration(hours: 4); // 4 giờ mới hiển thị lại

  // Khởi tạo AdMob (chỉ trên mobile)
  static Future<void> initialize() async {
    if (kIsWeb) {
      print('AdMob không được hỗ trợ trên web');
      return;
    }
    await MobileAds.instance.initialize();
  }

  // Tạo Banner Ad
  BannerAd createBannerAd() {
    if (kIsWeb) {
      throw UnsupportedError('Banner ads không được hỗ trợ trên web');
    }
    final adUnitId = Platform.isAndroid ? _bannerAdUnitIdAndroid : _bannerAdUnitIdIOS;
    
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
    final adUnitId = Platform.isAndroid ? _interstitialAdUnitIdAndroid : _interstitialAdUnitIdIOS;
    
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

  // Hiển thị Interstitial Ad
  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('Interstitial ad showed full screen content');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('Interstitial ad dismissed');
          ad.dispose();
          _interstitialAd = null;
          // Tạo ad mới cho lần tiếp theo
          createInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Interstitial ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
        },
      );
      _interstitialAd!.show();
    } else {
      print('Interstitial ad not ready');
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
    final adUnitId = Platform.isAndroid ? _appOpenAdUnitIdAndroid : _appOpenAdUnitIdIOS;
    
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

  // Dispose tất cả ads
  void disposeAll() {
    disposeBannerAd();
    disposeInterstitialAd();
    disposeAppOpenAd();
  }
}
