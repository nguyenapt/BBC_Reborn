import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/language_manager.dart';
import 'native_ad_theme.dart';
import 'passage_panel_decoration.dart';

enum TranscriptNativeAdSlot {
  /// Matches inactive transcript rows on episode transcript tab ([TranscriptSlide]).
  episodeTranscript,

  /// Matches transcript repeat role UI (`ListTile`-style chip) on speaking practice.
  speakingListTile,

  /// Same panel chrome as grammar passage overview block.
  grammarPassagePanel,

  /// Same card chrome as saved grammar rows on Saved screen.
  savedGrammarCard,
}

class TranscriptNativeAdWidget extends StatefulWidget {
  final String category;
  final TranscriptNativeAdSlot slot;

  const TranscriptNativeAdWidget({
    super.key,
    required this.category,
    this.slot = TranscriptNativeAdSlot.episodeTranscript,
  });

  @override
  State<TranscriptNativeAdWidget> createState() => _TranscriptNativeAdWidgetState();
}

class _TranscriptNativeAdWidgetState extends State<TranscriptNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _productionAdUnitId = 'ca-app-pub-2189112136936277/7442445947';

  final LanguageManager _languageManager = LanguageManager();

  String _getAdUnitId() {
    return kDebugMode ? _testAdUnitId : _productionAdUnitId;
  }

  static const double _minAttributionPx = 18;

  (TemplateType, double, double) _slotMetrics() {
    switch (widget.slot) {
      // Không dùng TemplateType.small: layout SDK dùng ImageView cho ảnh chính → AdMob
      // Native Validator báo "MediaView not used". Medium template có MediaView.
      case TranscriptNativeAdSlot.episodeTranscript:
      case TranscriptNativeAdSlot.speakingListTile:
        return (TemplateType.medium, 10, 260);
      case TranscriptNativeAdSlot.grammarPassagePanel:
        return (TemplateType.medium, 10, 220);
      case TranscriptNativeAdSlot.savedGrammarCard:
        return (TemplateType.medium, 12, 260);
    }
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoadAd());
    }
  }

  @override
  void didUpdateWidget(TranscriptNativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot != widget.slot) {
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
    final (templateType, radius, _) = _slotMetrics();
    _loadNativeAd(
      nativeTemplateStyleForColorScheme(
        scheme,
        templateType: templateType,
        cornerRadius: radius,
      ),
    );
  }

  void _loadNativeAd(NativeTemplateStyle templateStyle) {
    if (_isAdLoading) return;

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
            print('Transcript Native Ad loaded successfully');
          }
          if (!mounted) return;
          setState(() {
            _isAdLoaded = true;
            _isAdLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('Transcript Native Ad failed to load: $error');
          }
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
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

  String _attributionLabel() => _languageManager.getText('adAttributionLabel');

  Widget _adSizedBox(double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: _isAdLoaded && _nativeAd != null
          ? AdWidget(ad: _nativeAd!)
          : _isAdLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
    );
  }

  Widget _attributionRowEpisode(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: scheme.primary.withValues(alpha: 0.22),
          child: Text(
            'A',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minAttributionPx),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _attributionLabel().toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.65,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attributionRowCompact(ColorScheme scheme, {required double fontSize}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minAttributionPx),
      child: Row(
        children: [
          Icon(Icons.ads_click, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _attributionLabel(),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTranscriptChrome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (_, _, adHeight) = _slotMetrics();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _attributionRowEpisode(scheme),
              const SizedBox(height: 8),
              _adSizedBox(adHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakingListTileChrome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleMuted =
        scheme.onSurface.withValues(alpha: 0.88 * 0.65);
    final (_, _, adHeight) = _slotMetrics();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minAttributionPx),
              child: Text(
                _attributionLabel(),
                style: TextStyle(
                  color: subtitleMuted,
                  fontSize:
                      (Theme.of(context).textTheme.labelSmall?.fontSize ?? 12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _adSizedBox(adHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildGrammarPassageChrome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (_, _, adHeight) = _slotMetrics();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: passageOverviewPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _attributionRowCompact(scheme, fontSize: 13),
          const SizedBox(height: 8),
          _adSizedBox(adHeight),
        ],
      ),
    );
  }

  Widget _buildSavedCardChrome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (_, _, adHeight) = _slotMetrics();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _attributionRowCompact(scheme, fontSize: 14),
            const SizedBox(height: 10),
            _adSizedBox(adHeight),
          ],
        ),
      ),
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
        switch (widget.slot) {
          case TranscriptNativeAdSlot.episodeTranscript:
            return _buildEpisodeTranscriptChrome(context);
          case TranscriptNativeAdSlot.speakingListTile:
            return _buildSpeakingListTileChrome(context);
          case TranscriptNativeAdSlot.grammarPassagePanel:
            return _buildGrammarPassageChrome(context);
          case TranscriptNativeAdSlot.savedGrammarCard:
            return _buildSavedCardChrome(context);
        }
      },
    );
  }
}
