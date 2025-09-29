import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/episode.dart';

class FirebaseService {
  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';
  
  // Lấy dữ liệu HomePage từ Firebase
  Future<List<Category>> getHomePageData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/HomePage.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Category> categories = [];

        // Parse từng category và episodes của nó
        data.forEach((categoryName, categoryData) {
          if (categoryData is List) {
            final List<Episode> episodes = [];
            
            for (final episodeData in categoryData) {
              if (episodeData is Map<String, dynamic>) {
                episodes.add(Episode.fromJson(episodeData, episodeData['Id'] ?? ''));
              }
            }
            
            categories.add(Category(
              name: categoryName,
              episodes: episodes,
            ));
          }
        });

        // Sắp xếp categories theo tên
        categories.sort((a, b) => a.name.compareTo(b.name));
        
        return categories;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  // Lấy tất cả episodes từ một category cụ thể
  Future<List<Episode>> getEpisodesByCategory(String categoryName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/HomePage/$categoryName.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Episode> episodes = [];

        data.forEach((episodeId, episodeData) {
          if (episodeData is Map<String, dynamic>) {
            episodes.add(Episode.fromJson(episodeData, episodeId));
          }
        });

        return episodes;
      } else {
        throw Exception('Failed to load episodes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching episodes: $e');
    }
  }
}
