import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  final double? height;
  final EdgeInsetsGeometry? margin;
  
  const BannerAdWidget({
    Key? key,
    this.height,
    this.margin,
  }) : super(key: key);

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

  void _loadBannerAd() {
    try {
      _bannerAd = AdMobService().createBannerAd();
      _bannerAd?.load().then((_) {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      });
    } catch (e) {
      print('Banner ad not supported on this platform: $e');
      // Không cần set _isAdLoaded = true vì widget sẽ return SizedBox.shrink()
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Không hiển thị ads trên web
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
