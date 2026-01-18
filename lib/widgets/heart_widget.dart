import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/heart_service.dart';
import 'heart_slide_panel.dart';

/// Widget hiển thị hearts trên home page
class HeartWidget extends StatelessWidget {
  const HeartWidget({super.key});

  void _showSlidePanelFromTop(BuildContext context) {
    // Calculate header height to position panel right below the heart button
    // Header structure:
    // - Safe area top
    // - Top padding: 16
    // - Row content (logo 48px + heart button ~40px height): max is 48px
    // - Bottom padding: 16
    // We want panel to start right after the row (where heart button ends)
    // Include bottom padding to ensure panel doesn't overlap with heart button
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final headerTopPadding = 16.0;
    final rowHeight = 48.0; // Logo height, heart button is in same row
    final headerBottomPadding = 16.0;
    // Panel should start after the entire header (including bottom padding)
    // So: safeAreaTop + headerTopPadding + rowHeight + headerBottomPadding
    final panelTop = safeAreaTop + headerTopPadding + rowHeight + headerBottomPadding;
    
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
                    margin: EdgeInsets.only(top: panelTop),
                  ),
                ),
              ),
            ),
            // Panel mở rộng từ ngay dưới heart button xuống
            Positioned(
              top: panelTop + 4, // Thêm 4px margin để không che nút heart
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
        return GestureDetector(
          onTap: () => _showSlidePanelFromTop(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade100,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '${heartService.hearts}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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

