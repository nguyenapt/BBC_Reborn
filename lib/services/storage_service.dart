import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../models/favourite_episode.dart';
import 'auth_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _vocabulariesKey = 'saved_vocabularies';
  static const String _vocabularyItemsKey = 'saved_vocabulary_items';
  static const String _favouriteEpisodesDataKey = 'favourite_episodes_data';
  
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
  }


  /// Clear all data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vocabulariesKey);
    await prefs.remove(_vocabularyItemsKey);
    await prefs.remove(_favouriteEpisodesDataKey);
  }
}
