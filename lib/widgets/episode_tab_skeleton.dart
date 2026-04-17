import 'package:flutter/material.dart';

/// Placeholder khi đang tải nội dung đầy đủ (transcript/vocab/…) — tránh flash "No … available".
class EpisodeTabSkeleton extends StatelessWidget {
  final Color accentColor;
  final int lineCount;

  const EpisodeTabSkeleton({
    super.key,
    required this.accentColor,
    this.lineCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    final base = Color.lerp(
      Theme.of(context).colorScheme.surfaceContainerHighest,
      accentColor,
      0.08,
    )!.withOpacity(0.72);
    final w = MediaQuery.sizeOf(context).width - 32;
    final widths = [1.0, 0.88, 0.95, 0.72, 0.84, 0.9, 0.65, 0.92, 0.78, 0.86];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        for (var i = 0; i < lineCount; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: w * widths[i % widths.length],
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: w * widths[(i + 3) % widths.length],
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: i == lineCount - 1 ? 0 : 18),
        ],
      ],
    );
  }
}
