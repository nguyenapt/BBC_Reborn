import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/episode.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance = FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';
  static const String _favouritesPath = 'user_favourites';
  static const String _vocabulariesPath = 'user_vocabularies';

  /// Favourite Episodes Management
  Future<List<String>> getFavouriteEpisodeIds(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_favouritesPath/$userId.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.cast<String>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching favourite episodes: $e');
      return [];
    }
  }

  Future<List<Episode>> getFavouriteEpisodes(String userId) async {
    try {
      final favouriteIds = await getFavouriteEpisodeIds(userId);
      final List<Episode> favouriteEpisodes = [];

      // Load episodes from HomePage data
      final response = await http.get(
        Uri.parse('$_baseUrl/HomePage.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Search through all categories for favourite episodes
        data.forEach((categoryName, categoryData) {
          if (categoryData is List) {
            for (final episodeData in categoryData) {
              if (episodeData is Map<String, dynamic>) {
                final episodeId = episodeData['Id']?.toString() ?? '';
                if (favouriteIds.contains(episodeId)) {
                  favouriteEpisodes.add(Episode.fromJson(episodeData, episodeId));
                }
              }
            }
          }
        });
      }

      return favouriteEpisodes;
    } catch (e) {
      print('Error fetching favourite episodes: $e');
      return [];
    }
  }

  Future<bool> isEpisodeFavourite(String userId, String episodeId) async {
    final favouriteIds = await getFavouriteEpisodeIds(userId);
    return favouriteIds.contains(episodeId);
  }

  Future<void> addFavouriteEpisode(String userId, String episodeId) async {
    try {
      final favouriteIds = await getFavouriteEpisodeIds(userId);
      if (!favouriteIds.contains(episodeId)) {
        favouriteIds.add(episodeId);
        await _saveFavouriteIds(userId, favouriteIds);
      }
    } catch (e) {
      print('Error adding favourite episode: $e');
    }
  }

  Future<void> removeFavouriteEpisode(String userId, String episodeId) async {
    try {
      final favouriteIds = await getFavouriteEpisodeIds(userId);
      favouriteIds.remove(episodeId);
      await _saveFavouriteIds(userId, favouriteIds);
    } catch (e) {
      print('Error removing favourite episode: $e');
    }
  }

  Future<void> _saveFavouriteIds(String userId, List<String> favouriteIds) async {
    await http.put(
      Uri.parse('$_baseUrl/$_favouritesPath/$userId.json'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(favouriteIds),
    );
  }

  /// Vocabulary Management
  Future<List<String>> getSavedVocabularies(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_vocabulariesPath/$userId.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.cast<String>();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching saved vocabularies: $e');
      return [];
    }
  }

  Future<bool> isVocabularySaved(String userId, String vocabulary) async {
    final savedVocabularies = await getSavedVocabularies(userId);
    return savedVocabularies.contains(vocabulary);
  }

  Future<void> addVocabulary(String userId, String vocabulary) async {
    try {
      final savedVocabularies = await getSavedVocabularies(userId);
      if (!savedVocabularies.contains(vocabulary)) {
        savedVocabularies.add(vocabulary);
        await _saveVocabularies(userId, savedVocabularies);
      }
    } catch (e) {
      print('Error adding vocabulary: $e');
    }
  }

  Future<void> removeVocabulary(String userId, String vocabulary) async {
    try {
      final savedVocabularies = await getSavedVocabularies(userId);
      savedVocabularies.remove(vocabulary);
      await _saveVocabularies(userId, savedVocabularies);
    } catch (e) {
      print('Error removing vocabulary: $e');
    }
  }

  Future<void> _saveVocabularies(String userId, List<String> vocabularies) async {
    await http.put(
      Uri.parse('$_baseUrl/$_vocabulariesPath/$userId.json'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(vocabularies),
    );
  }

  /// Clear all data for user
  Future<void> clearAllUserData(String userId) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/$_favouritesPath/$userId.json'));
      await http.delete(Uri.parse('$_baseUrl/$_vocabulariesPath/$userId.json'));
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }
}



