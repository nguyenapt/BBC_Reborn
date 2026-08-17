import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/ads_interstitial_fallback_screen.dart';
import 'consent_service.dart';

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
  static const String _testRewardedInterstitialAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testRewardedInterstitialAdUnitIdIOS =
      'ca-app-pub-3940256099942544/6978759866';

  // Production Ad Unit IDs (thay thế bằng Ad Unit IDs thật khi publish)
  static const String _prodBannerAdUnitIdAndroid = 'ca-app-pub-2189112136936277/3489158520';
  static const String _prodBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _prodInterstitialAdUnitIdAndroid = 'ca-app-pub-2189112136936277/9862995184';
  static const String _prodInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _prodAppOpenAdUnitIdAndroid = 'ca-app-pub-2189112136936277/8760106002';
  static const String _prodAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';
  static const String _prodRewardedAdUnitIdAndroid =
      'ca-app-pub-2189112136936277/2424979553';
  static const String _prodRewardedAdUnitIdIOS =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _prodRewardedInterstitialAdUnitIdAndroid =
      'ca-app-pub-2189112136936277/6701827023';
  static const String _prodRewardedInterstitialAdUnitIdIOS =
      'ca-app-pub-3940256099942544/6978759866';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  /// True after UMP allows ads and [MobileAds.instance.initialize] completes.
  bool _sdkInitialized = false;

  bool get isSdkInitialized => _sdkInitialized;

  /// Call only after `await MobileAds.instance.initialize()`.
  void markSdkInitialized() {
    _sdkInitialized = true;
  }

  bool _guardSdkReady(String action) {
    if (kIsWeb) return false;
    if (_sdkInitialized) return true;
    debugPrint('AdMob: skip $action — MobileAds not initialized yet');
    return false;
  }

  /// Chờ UMP + [MobileAds.instance.initialize] (tối đa [timeout]).
  Future<bool> waitUntilSdkReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (kIsWeb) return false;
    if (_sdkInitialized) return true;
    final deadline = DateTime.now().add(timeout);
    while (!_sdkInitialized && DateTime.now().isBefore(deadline)) {
      final consent = ConsentService();
      if (consent.consentFlowFinished && !consent.canRequestAds) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _sdkInitialized;
  }
  DateTime? _lastInterstitialShownAt;
  int _interstitialShownCount = 0;
  AppOpenAd? _appOpenAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isLoadingRewarded = false;
  bool _isLoadingRewardedInterstitial = false;

  /// `true` = ưu tiên Rewarded Interstitial, classic Rewarded là fallback.
  /// Đặt `false` để quay lại ưu tiên Rewarded cổ điển.
  static bool preferRewardedInterstitial = true;
  
  // Thời gian lần cuối hiển thị App Open Ad (để tránh spam)
  DateTime? _lastAppOpenAdTime;
  DateTime? _appOpenAdLoadedAt;
  bool _isLoadingAppOpenAd = false;
  bool _isShowingAppOpenAd = false;
  bool _lastShownLoaded = false;
  int _appOpenShownThisSession = 0;

  static const Duration _appOpenAdCooldown = Duration(hours: 3); // 3 giờ mới hiển thị lại
  static const Duration _interstitialCooldown = Duration(seconds: 90);
  static const int _interstitialFallbackEvery = 5;
  static const Duration _maxAppOpenAdAge = Duration(hours: 4);
  static const int _maxAppOpenShowsPerSession = 2;
  static const String _appOpenLastShownPrefKey = 'admob.app_open.last_shown_iso';

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
      return Platform.isAndroid
          ? _testRewardedAdUnitIdAndroid
          : _testRewardedAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION Rewarded Ad Unit ID');
      return Platform.isAndroid
          ? _prodRewardedAdUnitIdAndroid
          : _prodRewardedAdUnitIdIOS;
    }
  }

  String _getRewardedInterstitialAdUnitId() {
    if (kDebugMode) {
      print('🔧 DEBUG MODE: Using TEST Rewarded Interstitial Ad Unit ID');
      return Platform.isAndroid
          ? _testRewardedInterstitialAdUnitIdAndroid
          : _testRewardedInterstitialAdUnitIdIOS;
    } else {
      print('🚀 PRODUCTION MODE: Using PRODUCTION Rewarded Interstitial Ad Unit ID');
      return Platform.isAndroid
          ? _prodRewardedInterstitialAdUnitIdAndroid
          : _prodRewardedInterstitialAdUnitIdIOS;
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
    if (!_guardSdkReady('createBannerAd')) {
      throw StateError('MobileAds SDK not initialized');
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

  /// Đang có interstitial sẵn sàng để show (không null sau onAdLoaded).
  bool get hasInterstitialReady => _interstitialAd != null;

  // Tạo Interstitial Ad (preload). Bỏ qua nếu đã có ad hoặc đang load.
  void createInterstitialAd() {
    if (!_guardSdkReady('createInterstitialAd')) return;
    if (_interstitialAd != null) {
      return;
    }
    if (_isLoadingInterstitial) {
      return;
    }
    _isLoadingInterstitial = true;
    final adUnitId = _getInterstitialAdUnitId();

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
          print('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// Chờ interstitial load (tối đa [timeout]). Gọi [createInterstitialAd] nếu chưa có và chưa đang load.
  Future<void> ensureInterstitialLoaded({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (kIsWeb) return;
    if (_interstitialAd != null) return;
    createInterstitialAd();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_interstitialAd != null) return;
      if (!_isLoadingInterstitial) return;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  bool _shouldShowFallbackNotice() {
    final nextShowOrdinal = _interstitialShownCount + 1;
    return nextShowOrdinal % _interstitialFallbackEvery == 0;
  }

  void _showInterstitialFallbackNotice(
    BuildContext context, {
    VoidCallback? onDismissedOrUnavailable,
  }) {
    _lastInterstitialShownAt = DateTime.now();
    _interstitialShownCount += 1;
    Navigator.of(context, rootNavigator: true)
        .push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AdsInterstitialFallbackScreen(
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    )
        .whenComplete(() {
      onDismissedOrUnavailable?.call();
    });
  }

  /// [onDismissedOrUnavailable] gọi sau khi ad đóng, lỗi hiển thị, hoặc không có ad sẵn (để điều hướng sau quảng cáo).
  void showInterstitialAd({
    VoidCallback? onDismissedOrUnavailable,
    BuildContext? context,
  }) {
    if (kIsWeb) {
      onDismissedOrUnavailable?.call();
      return;
    }
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null) {
      final sinceLast = now.difference(_lastInterstitialShownAt!);
      if (sinceLast < _interstitialCooldown) {
        print(
          'Interstitial in cooldown, remaining: ${_interstitialCooldown - sinceLast}',
        );
        onDismissedOrUnavailable?.call();
        return;
      }
    }
    if (context != null && _shouldShowFallbackNotice()) {
      _showInterstitialFallbackNotice(
        context,
        onDismissedOrUnavailable: onDismissedOrUnavailable,
      );
      return;
    }
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('Interstitial ad showed full screen content');
          _lastInterstitialShownAt = DateTime.now();
          _interstitialShownCount += 1;
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
      if (context != null) {
        _showInterstitialFallbackNotice(
          context,
          onDismissedOrUnavailable: onDismissedOrUnavailable,
        );
      } else {
        onDismissedOrUnavailable?.call();
      }
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

  Future<void> _loadLastShownTimeIfNeeded() async {
    if (_lastShownLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_appOpenLastShownPrefKey);
      if (iso != null && iso.isNotEmpty) {
        _lastAppOpenAdTime = DateTime.tryParse(iso);
      }
    } catch (e) {
      debugPrint('Failed to load app open last shown time: $e');
    } finally {
      _lastShownLoaded = true;
    }
  }

  Future<void> _saveLastShownTime(DateTime time) async {
    _lastAppOpenAdTime = time;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appOpenLastShownPrefKey, time.toIso8601String());
    } catch (e) {
      debugPrint('Failed to save app open last shown time: $e');
    }
  }

  // Tạo App Open Ad (idempotent)
  Future<void> createAppOpenAd() async {
    if (!_guardSdkReady('createAppOpenAd')) return;
    if (_isLoadingAppOpenAd || _appOpenAd != null) return;
    final adUnitId = _getAppOpenAdUnitId();
    _isLoadingAppOpenAd = true;

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenAdLoadedAt = DateTime.now();
          _isLoadingAppOpenAd = false;
          print('App Open ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('App Open ad failed to load: $error');
          _appOpenAd = null;
          _appOpenAdLoadedAt = null;
          _isLoadingAppOpenAd = false;
        },
      ),
    );
  }

  Future<void> preloadAppOpenAd() async {
    await createAppOpenAd();
  }

  bool _isAppOpenAdFresh() {
    final loadedAt = _appOpenAdLoadedAt;
    if (loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) <= _maxAppOpenAdAge;
  }

  Future<bool> canShowAppOpenAd() async {
    if (kIsWeb) return false;
    if (_isShowingAppOpenAd) return false;
    if (_appOpenShownThisSession >= _maxAppOpenShowsPerSession) {
      print('App Open ad blocked: reached session cap ($_maxAppOpenShowsPerSession)');
      return false;
    }
    await _loadLastShownTimeIfNeeded();
    if (_lastAppOpenAdTime == null) return true;
    final timeSinceLastAd = DateTime.now().difference(_lastAppOpenAdTime!);
    if (timeSinceLastAd < _appOpenAdCooldown) {
      print('App Open ad in cooldown, remaining: ${_appOpenAdCooldown - timeSinceLastAd}');
      return false;
    }
    return true;
  }

  // Hiển thị App Open Ad khi đủ điều kiện; trả về true nếu show thành công.
  Future<bool> showAppOpenAdIfReady({String trigger = 'unknown'}) async {
    if (!await canShowAppOpenAd()) return false;

    if (_appOpenAd == null || !_isAppOpenAdFresh()) {
      if (_appOpenAd != null) {
        _appOpenAd!.dispose();
        _appOpenAd = null;
        _appOpenAdLoadedAt = null;
      }
      await createAppOpenAd();
      print('App Open ad not ready/fresh for trigger=$trigger');
      return false;
    }

    if (_appOpenAd != null) {
      _isShowingAppOpenAd = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('App Open ad showed full screen content');
          _appOpenShownThisSession += 1;
          _saveLastShownTime(DateTime.now());
        },
        onAdDismissedFullScreenContent: (ad) {
          print('App Open ad dismissed');
          ad.dispose();
          _appOpenAd = null;
          _appOpenAdLoadedAt = null;
          _isShowingAppOpenAd = false;
          // Tạo ad mới cho lần tiếp theo
          createAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('App Open ad failed to show: $error');
          ad.dispose();
          _appOpenAd = null;
          _appOpenAdLoadedAt = null;
          _isShowingAppOpenAd = false;
          createAppOpenAd();
        },
      );
      _appOpenAd!.show();
      return true;
    } else {
      print('App Open ad not ready');
      createAppOpenAd();
      return false;
    }
  }

  // Dispose App Open ad
  void disposeAppOpenAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenAdLoadedAt = null;
    _isLoadingAppOpenAd = false;
    _isShowingAppOpenAd = false;
  }

  /// Prefetch reward ads. Ưu tiên RI khi [preferRewardedInterstitial]; luôn giữ classic Rewarded làm fallback.
  void createRewardedAd() {
    if (!_guardSdkReady('createRewardedAd')) return;
    if (preferRewardedInterstitial) {
      _loadRewardedInterstitialAd();
      _loadClassicRewardedAd();
    } else {
      _loadClassicRewardedAd();
      _loadRewardedInterstitialAd();
    }
  }

  void _loadRewardedInterstitialAd() {
    if (_rewardedInterstitialAd != null || _isLoadingRewardedInterstitial) {
      return;
    }
    _isLoadingRewardedInterstitial = true;
    final adUnitId = _getRewardedInterstitialAdUnitId();

    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isLoadingRewardedInterstitial = false;
          print('Rewarded interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Rewarded interstitial ad failed to load: $error');
          _rewardedInterstitialAd = null;
          _isLoadingRewardedInterstitial = false;
          // Fallback: đảm bảo classic rewarded đang được load.
          _loadClassicRewardedAd();
        },
      ),
    );
  }

  void _loadClassicRewardedAd() {
    if (_rewardedAd != null || _isLoadingRewarded) return;
    _isLoadingRewarded = true;
    final adUnitId = _getRewardedAdUnitId();

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          print('Classic rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('Classic rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  /// Hiện ad thưởng: ưu tiên theo [preferRewardedInterstitial], fallback format còn lại.
  void showRewardedAd({
    required Function() onRewarded,
    Function(String)? onAdFailedToShow,
  }) {
    if (preferRewardedInterstitial) {
      if (_rewardedInterstitialAd != null) {
        _showRewardedInterstitialAd(
          onRewarded: onRewarded,
          onAdFailedToShow: onAdFailedToShow,
        );
        return;
      }
      if (_rewardedAd != null) {
        print('Rewarded interstitial not ready — fallback to classic rewarded');
        _showClassicRewardedAd(
          onRewarded: onRewarded,
          onAdFailedToShow: onAdFailedToShow,
        );
        return;
      }
    } else {
      if (_rewardedAd != null) {
        _showClassicRewardedAd(
          onRewarded: onRewarded,
          onAdFailedToShow: onAdFailedToShow,
        );
        return;
      }
      if (_rewardedInterstitialAd != null) {
        print('Classic rewarded not ready — fallback to rewarded interstitial');
        _showRewardedInterstitialAd(
          onRewarded: onRewarded,
          onAdFailedToShow: onAdFailedToShow,
        );
        return;
      }
    }

    print('No rewarded / rewarded-interstitial ad ready');
    onAdFailedToShow?.call('Rewarded ad not ready');
    createRewardedAd();
  }

  void _showRewardedInterstitialAd({
    required Function() onRewarded,
    Function(String)? onAdFailedToShow,
  }) {
    final ad = _rewardedInterstitialAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (shown) {
        print('Rewarded interstitial showed full screen content');
      },
      onAdDismissedFullScreenContent: (shown) {
        print('Rewarded interstitial dismissed');
        shown.dispose();
        _rewardedInterstitialAd = null;
        createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        print('Rewarded interstitial failed to show: $error');
        shown.dispose();
        _rewardedInterstitialAd = null;
        if (_rewardedAd != null) {
          print('Show failed — trying classic rewarded fallback');
          _showClassicRewardedAd(
            onRewarded: onRewarded,
            onAdFailedToShow: onAdFailedToShow,
          );
        } else {
          onAdFailedToShow?.call(error.message);
          createRewardedAd();
        }
      },
    );

    ad.show(
      onUserEarnedReward: (shown, reward) {
        print(
          'User earned reward (rewarded interstitial): '
          '${reward.amount} ${reward.type}',
        );
        onRewarded();
      },
    );
  }

  void _showClassicRewardedAd({
    required Function() onRewarded,
    Function(String)? onAdFailedToShow,
  }) {
    final ad = _rewardedAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (shown) {
        print('Classic rewarded showed full screen content');
      },
      onAdDismissedFullScreenContent: (shown) {
        print('Classic rewarded dismissed');
        shown.dispose();
        _rewardedAd = null;
        createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (shown, error) {
        print('Classic rewarded failed to show: $error');
        shown.dispose();
        _rewardedAd = null;
        if (_rewardedInterstitialAd != null) {
          print('Show failed — trying rewarded interstitial fallback');
          _showRewardedInterstitialAd(
            onRewarded: onRewarded,
            onAdFailedToShow: onAdFailedToShow,
          );
        } else {
          onAdFailedToShow?.call(error.message);
          createRewardedAd();
        }
      },
    );

    ad.show(
      onUserEarnedReward: (shown, reward) {
        print(
          'User earned reward (classic rewarded): '
          '${reward.amount} ${reward.type}',
        );
        onRewarded();
      },
    );
  }

  bool isRewardedAdReady() {
    return _rewardedInterstitialAd != null || _rewardedAd != null;
  }

  void disposeRewardedAd() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    _isLoadingRewardedInterstitial = false;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoadingRewarded = false;
  }

  // Dispose tất cả ads
  void disposeAll() {
    disposeBannerAd();
    disposeInterstitialAd();
    disposeAppOpenAd();
    disposeRewardedAd();
  }
}
