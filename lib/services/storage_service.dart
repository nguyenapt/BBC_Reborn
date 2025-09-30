import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import 'auth_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _vocabulariesKey = 'saved_vocabularies';
  static const String _favouriteEpisodesDataKey = 'favourite_episodes_data';
  
  final AuthService _authService = AuthService();

  /// Favourite Episodes Management
  Future<List<Episode>> getFavouriteEpisodes() async {
    try {
      // Load episodes directly from local storage (stored as complete Episode objects)
      final prefs = await SharedPreferences.getInstance();
      final episodesJson = prefs.getString(_favouriteEpisodesDataKey);
      
      if (episodesJson == null) {
        debugPrint('No favourite episodes found in storage');
        return [];
      }
      
      final List<dynamic> episodesData = json.decode(episodesJson);
      final List<Episode> favouriteEpisodes = [];
      
      debugPrint('Total episodes in storage: ${episodesData.length}');
      
      for (final episodeData in episodesData) {
        try {
          final episode = Episode.fromJson(episodeData, episodeData['id']);
          favouriteEpisodes.add(episode);
          debugPrint('Added episode: ${episode.episodeName}');
        } catch (e) {
          debugPrint('Error parsing episode: $e');
        }
      }
      
      // Sort by published date (newest first)
      favouriteEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
      debugPrint('Loaded ${favouriteEpisodes.length} favourite episodes from local storage');
      return favouriteEpisodes;
    } catch (e) {
      debugPrint('Error loading favourite episodes: $e');
      return [];
    }
  }

  Future<List<String>> getFavouriteEpisodeIds() async {
    final episodes = await getFavouriteEpisodes();
    return episodes.map((e) => e.id).where((id) => id != null && id.isNotEmpty).cast<String>().toList();
  }

  Future<bool> isEpisodeFavourite(String episodeId) async {
    final episodes = await getFavouriteEpisodes();
    return episodes.any((e) => e.id == episodeId);
  }

  Future<void> addFavouriteEpisode(String episodeId, Episode episode) async {
    try {
      // Check if episode already exists
      final existingEpisodes = await getFavouriteEpisodes();
      if (existingEpisodes.any((e) => e.id == episodeId)) {
        debugPrint('Episode $episodeId already in favourites');
        return;
      }
      
      // Add new episode to the list
      existingEpisodes.add(episode);
      
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

  Future<void> _saveEpisodesList(List<Episode> episodes) async {
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


  /// Clear all data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vocabulariesKey);
    await prefs.remove(_favouriteEpisodesDataKey);
  }
}
