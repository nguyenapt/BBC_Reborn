import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  final double? height;
  final EdgeInsetsGeometry? margin;

  /// Khi true: banner adaptive theo chiều ngang available (rộng hơn banner 320 cố định).
  final bool adaptive;

  /// Chiều ngang (dp) cho adaptive; null = gần full screen width.
  final double? adaptiveWidth;

  /// AdMob collapsible: `top` | `bottom`. Null = banner thường.
  /// Collapsible cần adaptive anchored; widget sẽ tự bật adaptive.
  final String? collapsible;

  const BannerAdWidget({
    super.key,
    this.height,
    this.margin,
    this.adaptive = false,
    this.adaptiveWidth,
    this.collapsible,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _loadStarted = false;
  double _adHeight = 50;

  bool get _useAdaptive =>
      widget.adaptive || widget.collapsible == 'top' || widget.collapsible == 'bottom';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _loadBannerAd();
    }
  }

  Future<void> _loadBannerAd() async {
    if (kIsWeb) return;
    final ready = await AdMobService().waitUntilSdkReady();
    if (!mounted || !ready) return;
    try {
      AdSize size = AdSize.banner;
      if (_useAdaptive) {
        final width = (widget.adaptiveWidth ?? MediaQuery.sizeOf(context).width)
            .truncate()
            .clamp(320, 1200);
        final adaptive =
            await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          width,
        );
        if (adaptive != null) {
          size = adaptive;
        }
      }

      _bannerAd = AdMobService().createBannerAd(
        size: size,
        collapsible: widget.collapsible,
      );
      await _bannerAd?.load();
      if (mounted) {
        setState(() {
          _isAdLoaded = true;
          _adHeight = size.height.toDouble();
        });
      }
    } catch (e) {
      debugPrint('Banner ad load skipped: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _useAdaptive ? double.infinity : null,
      height: widget.height ?? _adHeight,
      margin: widget.margin ?? const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
