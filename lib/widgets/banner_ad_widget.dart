import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  final double? height;
  final EdgeInsetsGeometry? margin;

  const BannerAdWidget({
    super.key,
    this.height,
    this.margin,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    if (kIsWeb) return;
    final ready = await AdMobService().waitUntilSdkReady();
    if (!mounted || !ready) return;
    try {
      _bannerAd = AdMobService().createBannerAd();
      await _bannerAd?.load();
      if (mounted) {
        setState(() {
          _isAdLoaded = true;
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
      height: widget.height ?? 50,
      margin: widget.margin ?? const EdgeInsets.all(8.0),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
