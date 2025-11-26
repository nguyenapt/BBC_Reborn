import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/category_colors.dart';

class TranscriptNativeAdWidget extends StatefulWidget {
  final String category;

  const TranscriptNativeAdWidget({
    super.key,
    required this.category,
  });

  @override
  State<TranscriptNativeAdWidget> createState() => _TranscriptNativeAdWidgetState();
}

class _TranscriptNativeAdWidgetState extends State<TranscriptNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  // Test Ad Unit IDs
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  
  // Production Ad Unit IDs
  static const String _productionAdUnitId = 'ca-app-pub-2189112136936277/5841628891';
  
  String _getAdUnitId() {
    return kDebugMode ? _testAdUnitId : _productionAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (kIsWeb) {
      return;
    }
    
    if (_isAdLoading) return;
    
    setState(() {
      _isAdLoading = true;
    });

    _nativeAd = NativeAd(
      adUnitId: _getAdUnitId(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            print('Transcript Native Ad loaded successfully');
          }
          setState(() {
            _isAdLoaded = true;
            _isAdLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('Transcript Native Ad failed to load: $error');
          }
          setState(() {
            _isAdLoaded = false;
            _isAdLoading = false;
          });
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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    // Style giống với transcript items
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header giống transcript item (Speaker name)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: CategoryColors.getCategoryColor(widget.category),
                  ),
                ),
              ),
              // Time info (ẩn cho ad)
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 6),
          // Native Ad Content
          SizedBox(
            height: 200, // Chiều cao cố định cho native ad
            child: _isAdLoaded && _nativeAd != null
                ? AdWidget(ad: _nativeAd!)
                : _isAdLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            CategoryColors.getCategoryColor(widget.category),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(), // Không hiển thị gì nếu ad không load được
          ),
        ],
      ),
    );
  }
}

