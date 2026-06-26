import 'package:flutter/material.dart';
import 'dart:async';
import '../models/episode.dart';
import '../models/favourite_episode.dart';
import '../models/saved_grammar_item.dart';
import '../models/vocabulary_item.dart';
import '../services/api_daily_cache_service.dart';
import '../services/language_manager.dart';
import '../services/learning_analytics_service.dart';
import '../services/learning_progress_service.dart';
import '../models/episode_learning_progress.dart';
import '../services/saved_grammar_service.dart';
import '../services/storage_service.dart';
import '../services/vocabulary_service.dart';
import '../services/vocabulary_practice_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../services/review_reminder_service.dart';
import '../services/speaking_review_service.dart';
import '../services/achievement_service.dart';
import '../services/daily_goal_service.dart';
import '../widgets/achievements_section.dart';
import '../widgets/daily_goal_settings_tile.dart';
import '../widgets/episode_row.dart';
import '../widgets/grammar_explanation_widget.dart';
import '../widgets/segment_tab_slider.dart';
import '../widgets/transcript_native_ad_widget.dart';
import 'vocabulary_practice_screen.dart';
import '../theme/vocabulary_theme.dart';
import '../widgets/floating_bottom_nav_bar.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _savedSubPageController;
  int _savedSubPageIndex = 0;
  final StorageService _storageService = StorageService();
  final LanguageManager _languageManager = LanguageManager();
  final VocabularyService _vocabularyService = VocabularyService();
  final VocabularyPracticeService _vocabularyPracticeService = VocabularyPracticeService();
  final SavedGrammarService _savedGrammarService = SavedGrammarService();
  final ReviewReminderService _reviewReminderService = ReviewReminderService();
  final LearningAnalyticsService _analyticsService = LearningAnalyticsService();
  final LearningProgressService _learningProgress = LearningProgressService();
  final ApiDailyCacheService _apiDailyCacheService = ApiDailyCacheService();
  final SpeakingReviewService _speakingReviewService = SpeakingReviewService();

  late final VoidCallback _vocabularyListener;
  late final VoidCallback _savedGrammarListener;
  late final VoidCallback _learningProgressListener;

  List<FavouriteEpisode> _favouriteEpisodes = [];
  List<VocabularyItem> _savedVocabularies = [];
  List<SavedGrammarItem> _savedGrammarItems = [];
  final Map<String, Episode> _episodeLookup = {};

  bool _isLoadingFavourites = true;
  bool _isLoadingVocabularies = true;
  bool _isLoadingSavedGrammar = true;
  String? _favouritesError;
  String? _vocabulariesError;
  String? _savedGrammarError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _savedSubPageController = PageController();
    _vocabularyListener = () {
      if (mounted) {
        _loadSavedVocabularies();
      }
    };
    _savedGrammarListener = () {
      if (mounted) {
        _loadSavedGrammar();
      }
    };
    _learningProgressListener = () {
      if (mounted) setState(() {});
    };
    _vocabularyService.addListener(_vocabularyListener);
    _savedGrammarService.addListener(_savedGrammarListener);
    _learningProgress.addListener(_learningProgressListener);
    unawaited(_learningProgress.initialize());
    unawaited(_speakingReviewService.initialize());
    unawaited(AchievementService().initialize());
    unawaited(DailyGoalService().initialize());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _savedSubPageController.dispose();
    _vocabularyService.removeListener(_vocabularyListener);
    _savedGrammarService.removeListener(_savedGrammarListener);
    _learningProgress.removeListener(_learningProgressListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    await _vocabularyPracticeService.initialize();
    await _loadFavouriteEpisodes();
    await _loadSavedVocabularies();
    await _loadSavedGrammar();
    await _buildEpisodeLookup();
  }

  Future<void> _loadFavouriteEpisodes() async {
    setState(() {
      _isLoadingFavourites = true;
      _favouritesError = null;
    });

    try {
      _favouriteEpisodes = await _storageService.getFavouriteEpisodes();
    } catch (e) {
      _favouritesError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavourites = false;
        });
      }
    }
  }

  Future<void> _loadSavedVocabularies() async {
    setState(() {
      _isLoadingVocabularies = true;
      _vocabulariesError = null;
    });

    try {
      _savedVocabularies = _vocabularyService.savedVocabularies;
    } catch (e) {
      _vocabulariesError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVocabularies = false;
        });
      }
    }
  }

  Future<void> _loadSavedGrammar() async {
    setState(() {
      _isLoadingSavedGrammar = true;
      _savedGrammarError = null;
    });

    try {
      _savedGrammarItems = _savedGrammarService.items;
    } catch (e) {
      _savedGrammarError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedGrammar = false;
        });
      }
    }
  }

  Future<void> _buildEpisodeLookup() async {
    final lookup = <String, Episode>{};
    for (final fav in _favouriteEpisodes) {
      final episode = fav.toEpisode();
      if ((episode.id ?? '').isNotEmpty) {
        lookup[episode.id!] = episode;
      }
    }

    final requiredIds = <String>{};
    for (final vocab in _savedVocabularies) {
      if (vocab.bbcEpisodeId.isNotEmpty) {
        requiredIds.add(vocab.bbcEpisodeId);
      }
    }
    for (final grammar in _savedGrammarItems) {
      if (grammar.episodeId.isNotEmpty) {
        requiredIds.add(grammar.episodeId);
      }
    }
    requiredIds.removeWhere((id) => lookup.containsKey(id));

    if (requiredIds.isNotEmpty) {
      try {
        final remote = await _apiDailyCacheService
            .episodesMatchingFavouriteIds(requiredIds.toList());
        for (final episode in remote) {
          final id = episode.id ?? '';
          if (id.isNotEmpty) {
            lookup[id] = episode;
          }
        }
      } catch (e) {
        debugPrint('Cannot build full episode lookup: $e');
      }
    }

    if (mounted) {
      setState(() {
        _episodeLookup
          ..clear()
          ..addAll(lookup);
      });
    }
  }

  void _navigateToEpisode(Episode episode) {
    final categoryEpisodes = _episodeLookup.values.toList();
    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: categoryEpisodes.isNotEmpty ? categoryEpisodes : [episode],
    );
  }

  void _openEpisodeById(String episodeId) {
    final episode = _episodeLookup[episodeId];
    if (episode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageManager.getText('episodeDataUnavailable'))),
      );
      return;
    }
    _navigateToEpisode(episode);
  }

  Future<void> _removeVocabulary(String vocab) async {
    try {
      await _vocabularyService.removeVocabulary(vocab);
      await _loadSavedVocabularies();
      await _buildEpisodeLookup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('removedFromVocabularies')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('errorOccurred')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openVocabularyPractice({List<VocabularyItem>? initialWords}) {
    if (_savedVocabularies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_languageManager.getText('noVocabularyToPractice'))),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VocabularyPracticeScreen(
          allWords: _savedVocabularies,
          initialWords: initialWords,
        ),
      ),
    );
  }

  Future<void> _togglePinGrammar(SavedGrammarItem item) async {
    if (!item.isPinned) {
      await _maybeAskReviewReminderPermission();
    }
    await _savedGrammarService.setPinned(item.id, !item.isPinned);
    await _analyticsService.trackEvent('rule_saved');
    await _loadSavedGrammar();
    await _buildEpisodeLookup();
  }

  Future<void> _maybeAskReviewReminderPermission() async {
    final alreadyAsked = await _reviewReminderService.hasAskedPermission();
    if (alreadyAsked) return;
    if (!mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_languageManager.getText('enableReviewRemindersTitle')),
        content: Text(_languageManager.getText('enableReviewRemindersDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_languageManager.getText('later')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_languageManager.getText('allow')),
          ),
        ],
      ),
    );

    await _reviewReminderService.markAskedPermission();
    if (allow == true) {
      await _reviewReminderService.requestNotificationPermission();
    }
  }

  Future<void> _removeSavedGrammar(SavedGrammarItem item) async {
    await _savedGrammarService.removeById(item.id);
    await _loadSavedGrammar();
    await _buildEpisodeLookup();
  }

  Future<void> _markGrammarReviewed(SavedGrammarItem item) async {
    await _savedGrammarService.markReviewed(item.id);
    await _analyticsService.trackEvent('review_done');
    await LearningProgressService().recordActivity(LearningActivityType.grammarReview);
    await AchievementService().evaluateAll();
    await _loadSavedGrammar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [_languageManager, _vocabularyService, _savedGrammarService],
      ),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTodayTab(),
                    _buildWeekTab(),
                    _buildSavedLibraryTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [          
          // Title và subtitle
          Expanded(
            child: Text(
              _languageManager.getText('myLearning'),
              style: theme.textTheme.headlineSmall!.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // App icon đơn giản
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceVariant,
            ),
            child: Icon(
              Icons.auto_stories,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Theme.of(context).colorScheme.surface.withOpacity(0),
        tabs: [
          Tab(text: _languageManager.getText('myLearningToday')),
          Tab(text: _languageManager.getText('myLearningWeek')),
          Tab(text: _languageManager.getText('myLearningSaved')),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    final dueGrammar = _savedGrammarService.dueReviewItems.length;
    final dueVocab = _vocabularyPracticeService.buildPracticeDeck(_savedVocabularies).length;
    final dueSpeaking = _speakingReviewService.dueReviewItems.length;
    final continueProgress = _learningProgress.getMostRecentContinue();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (continueProgress != null)
          FutureBuilder<Episode?>(
            future: _learningProgress.resolveEpisodeForProgress(continueProgress),
            builder: (context, snapshot) {
              final episode = snapshot.data;
              if (episode == null) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.play_circle_fill),
                title: Text(_languageManager.getText('continueLearning')),
                subtitle: Text(episode.episodeName),
                onTap: () => _navigateToEpisode(episode),
              );
            },
          ),
        _buildTodayActionTile(
          icon: Icons.menu_book,
          title: _languageManager.getText('reviewToday'),
          subtitle: _languageManager.getTextWithParams('dueVocabCount', {'count': dueVocab}),
          enabled: dueVocab > 0,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VocabularyPracticeScreen(
                  allWords: _savedVocabularies,
                ),
              ),
            );
          },
        ),
        _buildTodayActionTile(
          icon: Icons.spellcheck,
          title: _languageManager.getText('grammar'),
          subtitle: _languageManager.getTextWithParams('dueGrammarCount', {'count': dueGrammar}),
          enabled: dueGrammar > 0,
          onTap: () => _tabController.animateTo(2),
        ),
        if (dueSpeaking > 0)
          _buildTodayActionTile(
            icon: Icons.mic,
            title: _languageManager.getText('speakingReviewTitle'),
            subtitle: _languageManager.getTextWithParams('speakingDueCount', {'count': dueSpeaking}),
            enabled: true,
            onTap: () => _tabController.animateTo(2),
          ),
        const AchievementsSection(),
        const DailyGoalSettingsTile(),
      ],
    );
  }

  Widget _buildTodayActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: enabled ? Theme.of(context).colorScheme.primary : null),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildWeekTab() {
    final week = _learningProgress.weekSummary();
    final listenMinutes = (week.listeningMs / 60000).round();
    final speakingAvg = week.speakingAverage.round();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildWeekStatCard(
          _languageManager.getText('weekListeningTitle'),
          _languageManager.getTextWithParams('weekListeningValue', {'minutes': listenMinutes}),
          Icons.headphones,
        ),
        _buildWeekStatCard(
          _languageManager.getText('weekVocabTitle'),
          _languageManager.getTextWithParams('weekVocabValue', {'count': week.vocabReviews}),
          Icons.bookmark,
        ),
        _buildWeekStatCard(
          _languageManager.getText('weekGrammarTitle'),
          _languageManager.getTextWithParams('weekGrammarValue', {'count': week.grammarReviews}),
          Icons.spellcheck,
        ),
        _buildWeekStatCard(
          _languageManager.getText('weekSpeakingTitle'),
          week.speakingAttempts > 0
              ? _languageManager.getTextWithParams('weekSpeakingValue', {
                  'avg': speakingAvg,
                  'count': week.speakingAttempts,
                })
              : _languageManager.getText('weekSpeakingEmpty'),
          Icons.mic,
        ),
      ],
    );
  }

  Widget _buildWeekStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedLibraryTab() {
    final accent = Theme.of(context).colorScheme.primary;
    final subTabs = [
      SegmentTabItem(
        icon: Icons.menu_book_rounded,
        label: _languageManager.getText('grammar'),
      ),
      SegmentTabItem(
        icon: Icons.headphones_rounded,
        label: _languageManager.getText('episodes'),
      ),
      SegmentTabItem(
        icon: Icons.translate_rounded,
        label: _languageManager.getText('vocabularies'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentTabSlider(
          tabs: subTabs,
          selectedIndex: _savedSubPageIndex,
          accentColor: accent,
          onSelected: (index) {
            setState(() => _savedSubPageIndex = index);
            _savedSubPageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          },
        ),
        Expanded(
          child: PageView(
            controller: _savedSubPageController,
            onPageChanged: (index) {
              setState(() => _savedSubPageIndex = index);
            },
            children: [
              _buildSavedGrammarTab(),
              _buildFavouriteEpisodesTab(),
              _buildVocabulariesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedGrammarTab() {
    if (_isLoadingSavedGrammar) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_savedGrammarError != null) {
      return Center(child: Text('${_languageManager.getText('errorOccurred')}: $_savedGrammarError'));
    }
    if (_savedGrammarItems.isEmpty) {
      return Center(
        child: Text(
          _languageManager.getText('noSavedGrammar'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65)),
        ),
      );
    }

    final dueItems = _savedGrammarService.dueReviewItems;
    final widgets = <Widget>[];
    if (dueItems.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.alarm, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_languageManager.getText('reviewQueueLabel')}: ${dueItems.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Insert a native ad at:
    // - position #5 (after 5 items) if total items > 5
    // - otherwise at the end
    final shouldInsertAfterFive = _savedGrammarItems.length > 5;
    final insertAfterItemIndex = 4; // 0-based -> 5th item
    var insertedAd = false;

    for (final item in _savedGrammarItems) {
      final hasEpisode =
          item.episodeId.isNotEmpty && _episodeLookup.containsKey(item.episodeId);
      final isDue = item.nextReviewAt != null &&
          !item.nextReviewAt!.isAfter(DateTime.now()) &&
          item.isPinned;
      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _analyticsService.trackEvent('grammar_opened');
              showDialog(
                context: context,
                builder: (dialogContext) => GrammarExplanationDialog(
                  explanation: item.toGrammarExplanation(),
                  category: item.category,
                  isSaved: item.isPinned,
                  onToggleSaved: () async {
                    await _togglePinGrammar(item);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  onOpenEpisode:
                      hasEpisode ? () => _openEpisodeById(item.episodeId) : null,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.isPinned ? Icons.bookmark : Icons.history,
                        color: item.isPinned
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.grammarPoint,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.sentence,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.episodeName.isNotEmpty
                                  ? item.episodeName
                                  : item.episodeId,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                            if (item.isPinned && item.nextReviewAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  isDue
                                      ? _languageManager.getText('reviewDueNow')
                                      : '${_languageManager.getText('nextReviewLabel')}: ${item.nextReviewAt!.toLocal().toString().split(' ').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDue
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                    fontWeight:
                                        isDue ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildInlineAction(
                        icon: item.isPinned
                            ? Icons.bookmark_remove_outlined
                            : Icons.bookmark_add_outlined,
                        label: item.isPinned
                            ? _languageManager.getText('unsave')
                            : _languageManager.getText('save'),
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () => _togglePinGrammar(item),
                      ),
                      if (item.isPinned)
                        _buildInlineAction(
                          icon: Icons.check_circle_outline,
                          label: _languageManager.getText('markReviewedLabel'),
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => _markGrammarReviewed(item),
                        ),
                      if (hasEpisode)
                        _buildInlineAction(
                          icon: Icons.open_in_new,
                          label: _languageManager.getText('openEpisode'),
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => _openEpisodeById(item.episodeId),
                        ),
                      _buildInlineAction(
                        icon: Icons.delete_outline,
                        label: _languageManager.getText('remove'),
                        color: Theme.of(context).colorScheme.error,
                        onTap: () => _removeSavedGrammar(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (!insertedAd &&
          shouldInsertAfterFive &&
          _savedGrammarItems.indexOf(item) == insertAfterItemIndex) {
        insertedAd = true;
        widgets.add(
          TranscriptNativeAdWidget(
            category: item.category,
            slot: TranscriptNativeAdSlot.savedGrammarCard,
          ),
        );
      }
    }

    if (!insertedAd) {
      widgets.add(
        const TranscriptNativeAdWidget(
          category: 'grammar',
          slot: TranscriptNativeAdSlot.savedGrammarCard,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSavedGrammar();
        await _buildEpisodeLookup();
      },
      child: ListView(
        padding: FloatingBottomNavBar.scrollPadding(context),
        children: widgets,
      ),
    );
  }

  Widget _buildFavouriteEpisodesTab() {
    if (_isLoadingFavourites) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(_languageManager.getText('loadingFavourites')),
          ],
        ),
      );
    }

    if (_favouritesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 16),
              Text(
                '${_languageManager.getText('errorOccurred')}: $_favouritesError',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFavouriteEpisodes,
                child: Text(_languageManager.getText('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_favouriteEpisodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noFavouriteEpisodes'),
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _languageManager.getText('addToFavouritesDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavouriteEpisodes,
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(context),
        itemCount: _favouriteEpisodes.length,
        itemBuilder: (context, index) {
          final favouriteEpisode = _favouriteEpisodes[index];
          final episode = favouriteEpisode.toEpisode();
          return EpisodeRow(
            episode: episode,
            onTap: () => _navigateToEpisode(episode),
            languageManager: _languageManager,
            learningProgress: _learningProgress.getProgressForEpisode(episode),
          );
        },
      ),
    );
  }

  Widget _buildVocabulariesTab() {
    if (_isLoadingVocabularies) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(_languageManager.getText('loadingVocabularies')),
          ],
        ),
      );
    }

    if (_vocabulariesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 16),
              Text(
                '${_languageManager.getText('errorOccurred')}: $_vocabulariesError',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSavedVocabularies,
                child: Text(_languageManager.getText('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_savedVocabularies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noSavedVocabularies'),
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _languageManager.getText('addToVocabulariesDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      );
    }

    final wotd = VocabularyPracticeService.pickWordOfTheDay(_savedVocabularies);
    final widgets = <Widget>[
      if (wotd != null) _buildWordOfTheDayCard(wotd),
    ];

    for (final vocabulary in _savedVocabularies) {
      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vocabulary.vocab,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (vocabulary.bbcEpisodeId.isNotEmpty)
                      IconButton(
                        tooltip: _languageManager.getText('openEpisode'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: Icon(
                          Icons.open_in_new,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        onPressed: () => _openEpisodeById(vocabulary.bbcEpisodeId),
                      ),
                    IconButton(
                      tooltip: _languageManager.getText('remove'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 22,
                      ),
                      onPressed: () => _removeVocabulary(vocabulary.vocab),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  vocabulary.mean,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.78),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const practiceButtonHeight = 52.0;
    const practiceButtonGap = 12.0;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadSavedVocabularies,
          child: ListView(
            padding: FloatingBottomNavBar.scrollPadding(
              context,
              extraBottom: practiceButtonHeight + practiceButtonGap,
            ),
            children: widgets,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: FloatingBottomNavBar.bottomInset(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, practiceButtonGap),
            child: Center(
              child: _buildFloatingPracticeButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOfTheDayCard(VocabularyItem item) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: VocabularyTheme.cardGradient,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageManager.getText('wordOfTheDay'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.vocab,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.mean,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _openVocabularyPractice(initialWords: [item]),
              style: FilledButton.styleFrom(
                backgroundColor: VocabularyTheme.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(_languageManager.getText('explore').toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingPracticeButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: VocabularyTheme.cardGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: VocabularyTheme.backgroundTop.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _openVocabularyPractice(),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(160, 52),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: Text(
          _languageManager.getText('practiceShort'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
