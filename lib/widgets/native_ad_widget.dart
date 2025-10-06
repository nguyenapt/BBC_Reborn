import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/category_colors.dart';

class NativeAdWidget extends StatefulWidget {
  final String category;
  final String? adUnitId;

  const NativeAdWidget({
    super.key,
    required this.category,
    this.adUnitId,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  // Test Ad Unit IDs - Thay thế bằng Ad Unit IDs thực tế của bạn
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110'; // Test Native Ad Unit ID
  
  // Production Ad Unit IDs (thay thế bằng Ad Unit IDs thực tế của bạn)
  static const String _productionAdUnitId = 'ca-app-pub-2189112136936277/5841628891'; // Production Native Ad Unit ID
  
  // Method để lấy ad unit ID phù hợp
  String _getAdUnitId() {
    // Nếu có adUnitId được truyền vào, sử dụng nó
    if (widget.adUnitId != null) {
      return widget.adUnitId!;
    }
    
    // Nếu không, sử dụng test ad unit cho debug, production cho release
    return kDebugMode ? _testAdUnitId : _productionAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    // Không load ads trên web
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
            print('Native Ad loaded successfully with ID: ${_getAdUnitId()}');
          }
          setState(() {
            _isAdLoaded = true;
            _isAdLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('Native Ad failed to load with ID: ${_getAdUnitId()}, Error: $error');
          }
          setState(() {
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

  @override
  Widget build(BuildContext context) {
    // Không hiển thị ads trên web
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với icon quảng cáo
          Row(
            children: [
              Icon(
                Icons.ads_click,
                color: CategoryColors.getCategoryColor(widget.category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sponsored Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CategoryColors.getCategoryColor(widget.category),
                ),
              ),
              const Spacer(),
              if (_isAdLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CategoryColors.getCategoryColor(widget.category),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Native Ad Content
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: _isAdLoaded && _nativeAd != null
                  ? AdWidget(ad: _nativeAd!)
                  : _isAdLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  CategoryColors.getCategoryColor(widget.category),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading ad...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ad not available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadNativeAd,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CategoryColors.getCategoryColor(widget.category),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
