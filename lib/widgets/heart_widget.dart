import 'package:flutter/material.dart';
import '../services/heart_service.dart';
import 'heart_slide_panel.dart';

/// Widget hiển thị hearts trên home page (hoặc AppBar khác khi truyền [panelTop]).
class HeartWidget extends StatelessWidget {
  const HeartWidget({super.key, this.panelTop, this.compact = false});

  /// Offset từ đỉnh màn hình tới điểm bắt đầu vùng dim + panel (giống bottom của header chứa nút heart).
  /// Nếu null, dùng layout header home (padding 16 + row 48 + padding 16).
  final double? panelTop;

  /// Gọn hơn (icon nhỏ hơn) — dùng cạnh [IconButton] trên AppBar cho đồng bộ với icon ~24.
  final bool compact;

  void _showSlidePanelFromTop(BuildContext context) {
    // Calculate header height to position panel right below the heart button
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final headerTopPadding = 16.0;
    final rowHeight = 48.0;
    final headerBottomPadding = 16.0;
    final resolvedPanelTop = panelTop ??
        (safeAreaTop + headerTopPadding + rowHeight + headerBottomPadding);
    
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
        // Animation mở rộng từ vị trí bottom của header (height = 0) xuống (height = maxHeight)
        final heightAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));

        return Stack(
          children: [
            // Barrier chỉ che phần dưới panel, không che header
            Positioned.fill(
              child: FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    margin: EdgeInsets.only(top: resolvedPanelTop),
                  ),
                ),
              ),
            ),
            // Panel mở rộng từ ngay dưới heart button xuống
            Positioned(
              top: resolvedPanelTop + 4, // Thêm 4px margin để không che nút heart
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
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,                        
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const HeartSlidePanel(),
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
    final heartService = HeartService();
    
    return ListenableBuilder(
      listenable: heartService,
      builder: (context, child) {
        final size = compact ? 30.0 : 36.0;
        final iconSize = compact ? 16.0 : 18.0;
        final innerPad = compact ? 5.0 : 6.0;
        final badgeRight = compact ? -3.0 : -4.0;
        final badgeTop = compact ? -3.0 : -4.0;
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
                    color: Colors.red.shade300,
                    width: compact ? 1.25 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade100,
                      blurRadius: compact ? 3 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.shade400,
                    size: iconSize,
                  ),
                ),
              ),
              Positioned(
                right: badgeRight,
                top: badgeTop,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 3 : 4,
                    vertical: compact ? 1 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '${heartService.hearts}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

