import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../models/favourite_episode.dart';
import '../models/saved_grammar_item.dart';
import 'auth_service.dart';
import 'user_cloud_sync_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _vocabulariesKey = 'saved_vocabularies';
  static const String _vocabularyItemsKey = 'saved_vocabulary_items';
  static const String _favouriteEpisodesDataKey = 'favourite_episodes_data';
  static const String _savedGrammarItemsKey = 'saved_grammar_items';
  static const String _aiCachePrefix = 'ai_cache_';
  
  final AuthService _authService = AuthService();

  /// Favourite Episodes Management
  Future<List<FavouriteEpisode>> getFavouriteEpisodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final episodesJson = prefs.getString(_favouriteEpisodesDataKey);
      
      if (episodesJson == null) {
        debugPrint('No favourite episodes found in storage');
        return [];
      }
      
      final List<dynamic> episodesData = json.decode(episodesJson);
      final List<FavouriteEpisode> favouriteEpisodes = [];
      
      debugPrint('Total episodes in storage: ${episodesData.length}');
      
      for (final episodeData in episodesData) {
        try {
          final favouriteEpisode = FavouriteEpisode.fromJson(episodeData);
          favouriteEpisodes.add(favouriteEpisode);
          debugPrint('Added favourite episode: ${favouriteEpisode.episodeName}');
        } catch (e) {
          debugPrint('Error parsing favourite episode: $e');
        }
      }
      
      // Sort by saved date (newest first)
      favouriteEpisodes.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      
      debugPrint('Loaded ${favouriteEpisodes.length} favourite episodes from local storage');
      return favouriteEpisodes;
    } catch (e) {
      debugPrint('Error loading favourite episodes: $e');
      return [];
    }
  }

  Future<List<String>> getFavouriteEpisodeIds() async {
    final episodes = await getFavouriteEpisodes();
    return episodes.map((e) => e.id).where((id) => id != null).cast<String>().toList();
  }

  Future<bool> isEpisodeFavourite(String episodeId) async {
    final episodes = await getFavouriteEpisodes();
    return episodes.any((e) => e.id == episodeId);
  }

  Future<void> addFavouriteEpisode(Episode episode) async {
    try {
      // Check if episode already exists
      final existingEpisodes = await getFavouriteEpisodes();
      if (existingEpisodes.any((e) => e.id == episode.id)) {
        debugPrint('Episode ${episode.id} already in favourites');
        return;
      }
      
      // Create FavouriteEpisode from Episode
      final favouriteEpisode = FavouriteEpisode.fromEpisode(episode);
      
      // Add new episode to the list
      existingEpisodes.add(favouriteEpisode);
      
      // Save updated list to local storage
      await _saveEpisodesList(existingEpisodes);
      
      debugPrint('Added episode ${episode.episodeName} to favourites');
      
      // If logged in, also save to Firebase
      if (_authService.isLoggedIn) {
        // This will be handled by the calling service
        debugPrint('User is logged in - will sync to Firebase');
      }
    } catch (e) {
      debugPrint('Error adding favourite episode: $e');
    }
  }

  Future<void> removeFavouriteEpisode(String episodeId) async {
    try {
      // Get current episodes and remove the one with matching ID
      final existingEpisodes = await getFavouriteEpisodes();
      existingEpisodes.removeWhere((e) => e.id == episodeId);
      
      // Save updated list to local storage
      await _saveEpisodesList(existingEpisodes);
      
      debugPrint('Removed episode $episodeId from favourites');
    } catch (e) {
      debugPrint('Error removing favourite episode: $e');
    }
  }

  Future<void> _saveEpisodesList(List<FavouriteEpisode> episodes) async {
    final prefs = await SharedPreferences.getInstance();
    final episodesData = episodes.map((e) => e.toJson()).toList();
    await prefs.setString(_favouriteEpisodesDataKey, json.encode(episodesData));
    UserCloudSyncService().schedulePush(priority: CloudPushPriority.urgent);
  }

  /// Vocabulary Management
  Future<List<String>> getSavedVocabularies() async {
    final prefs = await SharedPreferences.getInstance();
    final vocabulariesJson = prefs.getString(_vocabulariesKey);
    if (vocabulariesJson != null) {
      final List<dynamic> vocabularies = json.decode(vocabulariesJson);
      return vocabularies.cast<String>();
    }
    return [];
  }

  Future<bool> isVocabularySaved(String vocabulary) async {
    final savedVocabularies = await getSavedVocabularies();
    return savedVocabularies.contains(vocabulary);
  }

  Future<void> addVocabulary(String vocabulary) async {
    final savedVocabularies = await getSavedVocabularies();
    if (!savedVocabularies.contains(vocabulary)) {
      savedVocabularies.add(vocabulary);
      await _saveVocabularies(savedVocabularies);
      
      // If logged in, also save to Firebase
      if (_authService.isLoggedIn) {
        // This will be handled by the calling service
        debugPrint('User is logged in - will sync to Firebase');
      }
    }
  }

  Future<void> removeVocabulary(String vocabulary) async {
    final savedVocabularies = await getSavedVocabularies();
    savedVocabularies.remove(vocabulary);
    await _saveVocabularies(savedVocabularies);
  }

  Future<void> _saveVocabularies(List<String> vocabularies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vocabulariesKey, json.encode(vocabularies));
  }

  /// VocabularyItem Management (new methods)
  Future<List<VocabularyItem>> getSavedVocabularyItems() async {
    final prefs = await SharedPreferences.getInstance();
    final vocabulariesJson = prefs.getString(_vocabularyItemsKey);
    if (vocabulariesJson != null) {
      final List<dynamic> vocabularies = json.decode(vocabulariesJson);
      return vocabularies.map((v) => VocabularyItem(
        id: v['id'] ?? '',
        bbcEpisodeId: v['bbcEpisodeId'] ?? '',
        vocab: v['vocab'] ?? '',
        mean: v['mean'] ?? '',
      )).toList();
    }
    return [];
  }

  Future<void> saveVocabularyItems(List<VocabularyItem> vocabularies) async {
    final prefs = await SharedPreferences.getInstance();
    final vocabulariesData = vocabularies.map((v) => {
      'id': v.id,
      'bbcEpisodeId': v.bbcEpisodeId,
      'vocab': v.vocab,
      'mean': v.mean,
    }).toList();
    await prefs.setString(_vocabularyItemsKey, json.encode(vocabulariesData));
    UserCloudSyncService().schedulePush(priority: CloudPushPriority.urgent);
  }

  /// Saved Grammar Management
  Future<List<SavedGrammarItem>> getSavedGrammarItems() async {
    final prefs = await SharedPreferences.getInstance();
    final grammarJson = prefs.getString(_savedGrammarItemsKey);
    if (grammarJson == null || grammarJson.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> payload = json.decode(grammarJson);
      return payload
          .whereType<Map<String, dynamic>>()
          .map(SavedGrammarItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error loading saved grammar items: $e');
      return [];
    }
  }

  Future<void> saveSavedGrammarItems(List<SavedGrammarItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = items.map((item) => item.toJson()).toList();
    await prefs.setString(_savedGrammarItemsKey, json.encode(payload));
    UserCloudSyncService().schedulePush(priority: CloudPushPriority.urgent);
  }


  /// AI Cache Management
  Future<void> saveCachedData(String key, String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_aiCachePrefix$key', data);
    } catch (e) {
      debugPrint('Error saving cached data: $e');
    }
  }

  Future<String?> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_aiCachePrefix$key');
    } catch (e) {
      debugPrint('Error getting cached data: $e');
      return null;
    }
  }

  Future<void> removeCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_aiCachePrefix$key');
    } catch (e) {
      debugPrint('Error removing cached data: $e');
    }
  }

  Future<void> clearAICache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_aiCachePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing AI cache: $e');
    }
  }

  /// Ước lượng dung lượng AI cache local (UTF-16 code units ≈ 2 bytes/char).
  Future<int> getAICacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int total = 0;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_aiCachePrefix)) continue;
        total += key.length * 2;
        final value = prefs.get(key);
        if (value is String) {
          total += value.length * 2;
        } else if (value != null) {
          total += value.toString().length * 2;
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error getting AI cache size: $e');
      return 0;
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vocabulariesKey);
    await prefs.remove(_vocabularyItemsKey);
    await prefs.remove(_favouriteEpisodesDataKey);
    await prefs.remove(_savedGrammarItemsKey);
    await clearAICache();
  }
}
