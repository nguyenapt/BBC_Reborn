import 'package:flutter/material.dart';
import '../services/heart_service.dart';
import 'heart_slide_panel.dart';

/// Hearts trên home / AppBar. Trên Episode Detail truyền [episodeId] để hiện badge credits khi Pass đã mở.
class HeartWidget extends StatefulWidget {
  const HeartWidget({
    super.key,
    this.panelTop,
    this.compact = false,
    this.episodeId,
  });

  final double? panelTop;
  final bool compact;
  final String? episodeId;

  @override
  State<HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<HeartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _popScale;
  final HeartService _hearts = HeartService();
  int _displayedCredits = 0;
  int _lastSeenCredits = -1;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 2.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 2.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_popController);

    _syncCreditsFromService(animate: false);
    _hearts.addListener(_onHeartsChanged);
  }

  @override
  void didUpdateWidget(covariant HeartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _syncCreditsFromService(animate: false);
    }
  }

  @override
  void dispose() {
    _hearts.removeListener(_onHeartsChanged);
    _popController.dispose();
    super.dispose();
  }

  String? get _normalizedEpisodeId {
    final ep = widget.episodeId;
    if (ep == null) return null;
    final t = ep.trim();
    return t.isEmpty ? HeartService.miscScopeId : t;
  }

  void _syncCreditsFromService({required bool animate}) {
    final ep = widget.episodeId;
    if (ep == null) return;
    final next = _hearts.episodeCreditsRemaining(ep);
    if (!animate) {
      _lastSeenCredits = next;
      _displayedCredits = next;
      return;
    }
    if (next == _lastSeenCredits) return;

    final delta = _hearts.lastCreditDelta;
    final sameEpisode = _hearts.lastCreditEpisodeId == _normalizedEpisodeId;
    setState(() {
      _displayedCredits = next;
      _lastSeenCredits = next;
    });
    if (sameEpisode && delta != 0) {
      _popController.forward(from: 0);
    }
    _hearts.clearCreditDeltaHint();
  }

  void _onHeartsChanged() {
    if (!mounted) return;
    final ep = widget.episodeId;
    if (ep != null && _hearts.shouldShowEpisodeCreditBadge(ep)) {
      _syncCreditsFromService(animate: true);
    } else {
      setState(() {});
    }
  }

  void _showSlidePanelFromTop(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    const headerTopPadding = 16.0;
    const rowHeight = 48.0;
    const headerBottomPadding = 16.0;
    final resolvedPanelTop = widget.panelTop ??
        (safeAreaTop + headerTopPadding + rowHeight + headerBottomPadding);

    final ep = widget.episodeId;
    final creditMode =
        ep != null && _hearts.shouldShowEpisodeCreditBadge(ep);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final heightAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));

        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    margin: EdgeInsets.only(top: resolvedPanelTop),
                  ),
                ),
              ),
            ),
            Positioned(
              top: resolvedPanelTop + 4,
              left: 0,
              right: 0,
              child: SizedBox(
                width: double.infinity,
                child: SizeTransition(
                  sizeFactor: heightAnimation,
                  axisAlignment: -1.0,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height *
                            (creditMode ? 0.52 : 0.4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: HeartSlidePanel(
                        episodeId: creditMode ? ep : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episodeId;
    final showCredits =
        ep != null && _hearts.shouldShowEpisodeCreditBadge(ep);
    final credits = showCredits ? _displayedCredits : null;

    final size = widget.compact ? 30.0 : 36.0;
    final iconSize = widget.compact ? 16.0 : 18.0;
    final innerPad = widget.compact ? 5.0 : 6.0;
    final badgeRight = widget.compact ? -3.0 : -4.0;
    final badgeTop = widget.compact ? -3.0 : -4.0;

    final accent = showCredits ? Colors.teal : Colors.red;
    final icon = showCredits ? Icons.bolt_rounded : Icons.favorite;
    final badgeValue = showCredits ? '$credits' : '${_hearts.hearts}';

    return GestureDetector(
      onTap: () => _showSlidePanelFromTop(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(innerPad),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.shade300,
                width: widget.compact ? 1.25 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.shade100,
                  blurRadius: widget.compact ? 3 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: accent.shade400,
                size: iconSize,
              ),
            ),
          ),
          Positioned(
            right: badgeRight,
            top: badgeTop,
            child: ScaleTransition(
              scale: showCredits ? _popScale : const AlwaysStoppedAnimation(1),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 3 : 4,
                  vertical: widget.compact ? 1 : 2,
                ),
                decoration: BoxDecoration(
                  color: accent.shade400,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  badgeValue,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.compact ? 9 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
