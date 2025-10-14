import 'package:flutter/material.dart';

class GrowthIcon extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const GrowthIcon({
    super.key,
    this.size = 24,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFFE8F5E8); // Light mint green
    final iconColor = this.iconColor ?? const Color(0xFF4CAF50); // Darker green

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.2), // 20% of size for rounded corners
      ),
      child: CustomPaint(
        painter: GrowthIconPainter(iconColor),
        size: Size(size, size),
      ),
    );
  }
}

class GrowthIconPainter extends CustomPainter {
  final Color color;

  GrowthIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08 // 8% of size
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Calculate positions based on size
    final padding = size.width * 0.15; // 15% padding
    final usableWidth = size.width - (padding * 2);
    final usableHeight = size.height - (padding * 2);
    
    // Start point (bottom left)
    final startX = padding;
    final startY = size.height - padding;
    
    // Create zigzag growth pattern
    final segments = 4; // Number of zigzag segments
    final segmentWidth = usableWidth / segments;
    final segmentHeight = usableHeight / segments;
    
    path.moveTo(startX, startY);
    
    for (int i = 0; i < segments; i++) {
      final x = startX + (segmentWidth * (i + 1));
      final y = startY - (segmentHeight * (i + 1));
      
      if (i == 0) {
        // First segment: diagonal up
        path.lineTo(x, y);
      } else {
        // Subsequent segments: zigzag pattern
        final midX = startX + (segmentWidth * i) + (segmentWidth * 0.5);
        final midY = startY - (segmentHeight * i) - (segmentHeight * 0.3);
        
        path.lineTo(midX, midY);
        path.lineTo(x, y);
      }
    }
    
    // Draw the path
    canvas.drawPath(path, paint);
    
    // Draw arrow at the end
    final arrowSize = size.width * 0.12;
    final arrowX = size.width - padding;
    final arrowY = padding;
    
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final arrowPath = Path();
    arrowPath.moveTo(arrowX, arrowY);
    arrowPath.lineTo(arrowX - arrowSize, arrowY + arrowSize);
    arrowPath.lineTo(arrowX - arrowSize * 0.6, arrowY + arrowSize * 0.3);
    arrowPath.lineTo(arrowX - arrowSize * 0.6, arrowY + arrowSize);
    arrowPath.lineTo(arrowX, arrowY);
    arrowPath.close();
    
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

