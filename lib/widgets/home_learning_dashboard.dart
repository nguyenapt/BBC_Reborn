import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/episode_learning_progress.dart';
import '../models/vocabulary_item.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';
import '../theme/vocabulary_theme.dart';

/// Khoảng cách đều giữa các section trên Home (mục tiêu, tiếp tục học, WOTD, episode mới…).
const double kHomeSectionSpacing = 10;
const double _kDashboardCardHeight = 80;
const EdgeInsets _kDashboardCardPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);
const double _kDashboardLeadingSize = 36;
const double _kDashboardLineHeight = 1.15;
const double _kDashboardThirdLineHeight = 14;
const double _kDashboardProgressHeight = 4;

TextStyle _dashboardLabelStyle({
  required Color color,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return TextStyle(
    fontSize: 12,
    height: _kDashboardLineHeight,
    fontWeight: fontWeight,
    color: color,
  );
}

TextStyle _dashboardTitleStyle({
  required Color color,
  FontWeight fontWeight = FontWeight.w800,
}) {
  return TextStyle(
    fontSize: 15,
    height: _kDashboardLineHeight,
    fontWeight: fontWeight,
    color: color,
  );
}

TextStyle _dashboardSubtitleStyle({required Color color}) {
  return TextStyle(
    fontSize: 12,
    height: _kDashboardLineHeight,
    color: color,
  );
}

Widget _dashboardProgressBar({
  required double? value,
  required Color backgroundColor,
  Color? valueColor,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: double.infinity,
        height: _kDashboardProgressHeight,
        child: LinearProgressIndicator(
          value: value,
          minHeight: _kDashboardProgressHeight,
          backgroundColor: backgroundColor,
          valueColor: valueColor != null
              ? AlwaysStoppedAnimation<Color>(valueColor)
              : null,
        ),
      ),
    ),
  );
}

Widget _dashboardEllipsisText(String text, TextStyle style) {
  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
    style: style,
  );
}

class _DashboardTextColumn extends StatelessWidget {
  final String label;
  final String title;
  final Widget thirdLine;
  final TextStyle labelStyle;
  final TextStyle titleStyle;

  const _DashboardTextColumn({
    required this.label,
    required this.title,
    required this.thirdLine,
    required this.labelStyle,
    required this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardEllipsisText(label, labelStyle),
        _dashboardEllipsisText(title, titleStyle),
        SizedBox(
          width: double.infinity,
          height: _kDashboardThirdLineHeight,
          child: thirdLine,
        ),
      ],
    );
  }
}

class HomeLearningDashboard extends StatelessWidget {
  final EpisodeLearningProgress? continueProgress;
  final Episode? continueEpisode;
  final int dueVocabCount;
  final int dueGrammarCount;
  final VocabularyItem? wordOfTheDay;
  final Episode? latestEpisode;
  final VoidCallback? onContinueTap;
  final VoidCallback? onReviewVocabTap;
  final VoidCallback? onReviewGrammarTap;
  final VoidCallback? onWordOfDayTap;
  final VoidCallback? onLatestEpisodeTap;

  const HomeLearningDashboard({
    super.key,
    this.continueProgress,
    this.continueEpisode,
    this.dueVocabCount = 0,
    this.dueGrammarCount = 0,
    this.wordOfTheDay,
    this.latestEpisode,
    this.onContinueTap,
    this.onReviewVocabTap,
    this.onReviewGrammarTap,
    this.onWordOfDayTap,
    this.onLatestEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (continueProgress != null && continueEpisode != null) {
      children.add(
        _ContinueCard(
          progress: continueProgress!,
          episode: continueEpisode!,
          onTap: onContinueTap,
        ),
      );
    }

    if (dueVocabCount > 0 || dueGrammarCount > 0) {
      children.add(
        _ReviewTodayCard(
          dueVocabCount: dueVocabCount,
          dueGrammarCount: dueGrammarCount,
          onVocabTap: onReviewVocabTap,
          onGrammarTap: onReviewGrammarTap,
        ),
      );
    }

    if (wordOfTheDay != null) {
      children.add(_WordOfDayCard(word: wordOfTheDay!, onTap: onWordOfDayTap));
    }

    if (latestEpisode != null) {
      children.add(
        _LatestEpisodeCard(episode: latestEpisode!, onTap: onLatestEpisodeTap),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, kHomeSectionSpacing, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: kHomeSectionSpacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final EpisodeLearningProgress progress;
  final Episode episode;
  final VoidCallback? onTap;

  const _ContinueCard({
    required this.progress,
    required this.episode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = progress.listenProgressRatio;

    return Material(
      color: colorScheme.primaryContainer.withOpacity(0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: _kDashboardCardHeight,
          child: Padding(
            padding: _kDashboardCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageCacheService().buildCachedImage(
                    imageUrl: episode.thumbImage,
                    width: _kDashboardLeadingSize,
                    height: _kDashboardLeadingSize,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    showWatermark: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DashboardTextColumn(
                    label: lm.getText('continueLearning'),
                    title: episode.episodeName,
                    labelStyle: _dashboardLabelStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                    titleStyle: _dashboardTitleStyle(
                      color: theme.textTheme.bodyMedium?.color ??
                          colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    thirdLine: _dashboardProgressBar(
                      value: ratio > 0 ? ratio : null,
                      backgroundColor:
                          colorScheme.outlineVariant.withOpacity(0.35),
                      valueColor: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewTodayCard extends StatelessWidget {
  final int dueVocabCount;
  final int dueGrammarCount;
  final VoidCallback? onVocabTap;
  final VoidCallback? onGrammarTap;

  const _ReviewTodayCard({
    required this.dueVocabCount,
    required this.dueGrammarCount,
    this.onVocabTap,
    this.onGrammarTap,
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lm.getText('reviewToday'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (dueVocabCount > 0)
            _ReviewTodayAction(
              icon: Icons.style_outlined,
              label: lm.getTextWithParams('dueVocabCount', {'count': dueVocabCount}),
              onTap: onVocabTap,
            ),
          if (dueVocabCount > 0 && dueGrammarCount > 0) const SizedBox(height: 8),
          if (dueGrammarCount > 0)
            _ReviewTodayAction(
              icon: Icons.menu_book_outlined,
              label: lm.getTextWithParams('dueGrammarCount', {'count': dueGrammarCount}),
              onTap: onGrammarTap,
            ),
        ],
      ),
    );
  }
}

class _ReviewTodayAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ReviewTodayAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordOfDayCard extends StatelessWidget {
  final VocabularyItem word;
  final VoidCallback? onTap;

  const _WordOfDayCard({required this.word, this.onTap});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: VocabularyTheme.cardGradient,
          ),
          child: SizedBox(
            height: _kDashboardCardHeight,
            child: Padding(
              padding: _kDashboardCardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: _kDashboardLeadingSize,
                    height: _kDashboardLeadingSize,
                    decoration: BoxDecoration(
                      color: VocabularyTheme.accentGreen.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.style_outlined,
                      color: VocabularyTheme.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardTextColumn(
                      label: lm.getText('wordOfTheDay'),
                      title: word.vocab,
                      labelStyle: _dashboardLabelStyle(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      titleStyle: _dashboardTitleStyle(
                        color: Colors.white,
                      ),
                      thirdLine: _dashboardEllipsisText(
                        word.mean.isNotEmpty ? word.mean : ' ',
                        _dashboardSubtitleStyle(
                          color: Colors.white.withOpacity(
                            word.mean.isNotEmpty ? 0.88 : 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestEpisodeCard extends StatelessWidget {
  final Episode episode;
  final VoidCallback? onTap;

  const _LatestEpisodeCard({required this.episode, this.onTap});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: _kDashboardCardHeight,
          padding: _kDashboardCardPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: _kDashboardLeadingSize,
                height: _kDashboardLeadingSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fiber_new_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardTextColumn(
                  label: lm.getText('newEpisode'),
                  title: episode.episodeName,
                  labelStyle: _dashboardLabelStyle(
                    color: colorScheme.primary,
                  ),
                  titleStyle: _dashboardTitleStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  thirdLine: Text(
                    ' ',
                    style: _dashboardSubtitleStyle(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withOpacity(0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
