import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../services/language_manager.dart';
import 'native_ad_theme.dart';

enum NativeAdLayout {
  /// Tab content style with visible attribution header (e.g. vocabulary empty state).
  embedded,

  /// Minimal chrome; ad fills remaining space (interstitial fallback route).
  interstitialFallback,
}

class NativeAdWidget extends StatefulWidget {
  /// Min width khuyến nghị cho TemplateType.medium (AdMob validator).
  static const double embeddedMediumMinWidth = 320;
  static const double embeddedMediumAdHeight = 320;

  final String category;
  final String? adUnitId;
  final NativeAdLayout layout;

  const NativeAdWidget({
    super.key,
    required this.category,
    this.adUnitId,
    this.layout = NativeAdLayout.embedded,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _productionAdUnitIdAndroid =
      'ca-app-pub-2189112136936277/7442445947';
  static const String _productionAdUnitIdIOS =
      'ca-app-pub-2189112136936277/5062792399';

  final LanguageManager _languageManager = LanguageManager();

  static const double _minAttributionPx = 18;

  String _getAdUnitId() {
    if (widget.adUnitId != null) {
      return widget.adUnitId!;
    }
    return kDebugMode
        ? _testAdUnitId
        : (Platform.isIOS ? _productionAdUnitIdIOS : _productionAdUnitIdAndroid);
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoadAd());
    }
  }

  @override
  void didUpdateWidget(NativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout ||
        oldWidget.adUnitId != widget.adUnitId) {
      _nativeAd?.dispose();
      _nativeAd = null;
      _isAdLoaded = false;
      _isAdLoading = false;
      if (!kIsWeb && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoadAd());
      }
    }
  }

  void _scheduleLoadAd() {
    if (!mounted || kIsWeb) return;
    final scheme = Theme.of(context).colorScheme;
    unawaited(_loadNativeAdWhenReady(
      nativeTemplateStyleForColorScheme(
        scheme,
        templateType: TemplateType.medium,
        cornerRadius: 12,
      ),
    ));
  }

  Future<void> _loadNativeAdWhenReady(NativeTemplateStyle templateStyle) async {
    final ready = await AdMobService().waitUntilSdkReady();
    if (!mounted || !ready) return;
    _loadNativeAd(templateStyle);
  }

  void _loadNativeAd(NativeTemplateStyle templateStyle) {
    if (_isAdLoading) return;
    if (!AdMobService().isSdkInitialized) return;

    setState(() {
      _isAdLoading = true;
    });

    _nativeAd?.dispose();
    _nativeAd = NativeAd(
      adUnitId: _getAdUnitId(),
      nativeTemplateStyle: templateStyle,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            print('Native Ad loaded successfully with ID: ${_getAdUnitId()}');
          }
          if (!mounted) return;
          setState(() {
            _isAdLoaded = true;
            _isAdLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print(
              'Native Ad failed to load with ID: ${_getAdUnitId()}, Error: $error',
            );
          }
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isAdLoaded = false;
            _isAdLoading = false;
          });
        },
        onAdClicked: (ad) {
          if (kDebugMode) {
            print('Native Ad clicked');
          }
        },
        onAdImpression: (ad) {
          if (kDebugMode) {
            print('Native Ad impression recorded');
          }
        },
      ),
      request: const AdRequest(),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Widget _adBody(ColorScheme colorScheme) {
    return _isAdLoaded && _nativeAd != null
        ? AdWidget(ad: _nativeAd!)
        : _isAdLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _languageManager.getText('loadingAd'),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ads_click_outlined,
                      size: 48,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _languageManager.getText('adNotAvailable'),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _scheduleLoadAd(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: Text(_languageManager.getText('retry')),
                    ),
                  ],
                ),
              );
  }

  Widget _embeddedBuild(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.ads_click,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: _minAttributionPx),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _languageManager.getText('adAttributionLabel'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isAdLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: NativeAdWidget.embeddedMediumAdHeight,
              child: _adBody(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interstitialFallbackBuild(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.ads_click, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minAttributionPx),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _languageManager.getText('adAttributionLabel'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            ),
            if (_isAdLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.28),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _adBody(colorScheme),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        switch (widget.layout) {
          case NativeAdLayout.embedded:
            return _embeddedBuild(context);
          case NativeAdLayout.interstitialFallback:
            return _interstitialFallbackBuild(context);
        }
      },
    );
  }
}
