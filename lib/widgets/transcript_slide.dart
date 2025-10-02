import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';

class TranscriptSlide extends StatelessWidget {
  final Episode episode;

  const TranscriptSlide({
    super.key,
    required this.episode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.description,
                color: CategoryColors.getCategoryColor(episode.category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcript',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CategoryColors.getCategoryColor(episode.category),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Transcript Content
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
              child: SingleChildScrollView(
                child: Text(
                  episode.transcriptHtml ?? episode.transcript,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface,
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




