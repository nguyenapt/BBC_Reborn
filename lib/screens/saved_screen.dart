import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/favourite_episode.dart';
import '../models/saved_grammar_item.dart';
import '../models/vocabulary_item.dart';
import '../services/api_daily_cache_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/language_manager.dart';
import '../services/learning_analytics_service.dart';
import '../services/saved_grammar_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../services/vocabulary_service.dart';
import '../services/vocabulary_practice_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../services/review_reminder_service.dart';
import '../widgets/episode_row.dart';
import '../widgets/grammar_explanation_widget.dart';
import '../widgets/transcript_native_ad_widget.dart';
import 'vocabulary_practice_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key});

  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();
  final FirebaseStorageService _firebaseStorageService = FirebaseStorageService();
  final UserService _userService = UserService();
  final LanguageManager _languageManager = LanguageManager();
  final AuthService _authService = AuthService();
  final VocabularyService _vocabularyService = VocabularyService();
  final VocabularyPracticeService _vocabularyPracticeService = VocabularyPracticeService();
  final SavedGrammarService _savedGrammarService = SavedGrammarService();
  final ReviewReminderService _reviewReminderService = ReviewReminderService();
  final LearningAnalyticsService _analyticsService = LearningAnalyticsService();
  final ApiDailyCacheService _apiDailyCacheService = ApiDailyCacheService();

  late final VoidCallback _vocabularyListener;
  late final VoidCallback _savedGrammarListener;

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
    _vocabularyService.addListener(_vocabularyListener);
    _savedGrammarService.addListener(_savedGrammarListener);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vocabularyService.removeListener(_vocabularyListener);
    _savedGrammarService.removeListener(_savedGrammarListener);
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
      final localEpisodes = await _storageService.getFavouriteEpisodes();
      if (localEpisodes.isNotEmpty) {
        _favouriteEpisodes = localEpisodes;
      } else if (_authService.isLoggedIn) {
        try {
          final firebaseEpisodes =
              await _firebaseStorageService.getFavouriteEpisodes(_userService.userId);
          _favouriteEpisodes = firebaseEpisodes
              .map((episode) => FavouriteEpisode.fromEpisode(episode))
              .toList();
        } catch (firebaseError) {
          debugPrint('Firebase load failed: $firebaseError');
        }
      }
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
                    _buildSavedGrammarTab(),
                    _buildFavouriteEpisodesTab(),
                    _buildVocabulariesTab(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageManager.getText('myLearning'),
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _languageManager.getText('myLearningDesc'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
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
          Tab(text: _languageManager.getText('grammar')),
          Tab(text: _languageManager.getText('episodes')),
          Tab(text: _languageManager.getText('vocabularies')),
        ],
      ),
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
      child: ListView(children: widgets),
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
        itemCount: _favouriteEpisodes.length,
        itemBuilder: (context, index) {
          final favouriteEpisode = _favouriteEpisodes[index];
          final episode = favouriteEpisode.toEpisode();
          return EpisodeRow(
            episode: episode,
            onTap: () => _navigateToEpisode(episode),
            languageManager: _languageManager,
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

    widgets.add(const SizedBox(height: 96));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadSavedVocabularies,
          child: ListView(children: widgets),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Center(
              child: _buildFloatingPracticeButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOfTheDayCard(VocabularyItem item) {
    const backgroundTop = Color(0xFF0D5D85);
    const backgroundBottom = Color(0xFF0A4B6B);
    const exploreGreen = Color(0xFF66C95B);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundTop, backgroundBottom],
          ),
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
                backgroundColor: exploreGreen,
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
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0D5D85),
            Color(0xFF0A4B6B),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D5D85).withOpacity(0.35),
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
