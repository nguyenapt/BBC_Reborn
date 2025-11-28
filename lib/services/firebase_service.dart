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
          if (categoryName == 'Grammar') {
            return;
          }
          if (categoryData is List) {
            final List<Episode> episodes = [];
            
            for (final episodeData in categoryData) {
              if (episodeData is Map<String, dynamic>) {
                try {
                  final episodeId = episodeData['Id']?.toString() ?? '';
                  if (episodeId.isNotEmpty) {
                    episodes.add(Episode.fromJson(episodeData, episodeId));
                  }
                } catch (e) {
                  print('Error parsing episode: $e');
                  // Skip episode này và tiếp tục
                }
              }
            }
            
            if (episodes.isNotEmpty) {
              categories.add(Category(
                name: categoryName,
                episodes: episodes,
              ));
            }
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

  // Lấy dữ liệu category theo năm (cho CategoriesScreen)
  static Future<List<Episode>> getCategoryData(String category, int year) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$category/$year.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        final List<Episode> episodes = [];

        if (data is Map<String, dynamic>) {
          // Trường hợp API trả về Map với nhiều episodes
          data.forEach((episodeId, episodeData) {
            if (episodeData is Map<String, dynamic>) {
              episodes.add(Episode.fromJson(episodeData, episodeId));
            }
          });
        } else if (data is List) {
          // Trường hợp API trả về List
          for (int i = 0; i < data.length; i++) {
            final episodeData = data[i];
            if (episodeData is Map<String, dynamic>) {
              final episodeId = episodeData['Id']?.toString() ?? i.toString();
              episodes.add(Episode.fromJson(episodeData, episodeId));
            }
          }
        } else if (data is Map<String, dynamic> && data.containsKey('Id')) {
          // Trường hợp API trả về một episode duy nhất (như REE/2025/0.json)
          final episodeId = data['Id']?.toString() ?? '0';
          episodes.add(Episode.fromJson(data, episodeId));
        }

        // Sắp xếp theo PublishedDate (mới nhất trước)
        episodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));

        return episodes;
      } else {
        throw Exception('Failed to load category data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching category data: $e');
    }
  }

  // Lấy dữ liệu category trực tiếp (không có year) - cho Other Programs
  static Future<List<Episode>> getCategoryDataWithoutYear(String category) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$category.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        final List<Episode> episodes = [];

        if (data is Map<String, dynamic>) {
          // Trường hợp API trả về Map với nhiều episodes
          data.forEach((episodeId, episodeData) {
            if (episodeData is Map<String, dynamic>) {
              episodes.add(Episode.fromJson(episodeData, episodeId));
            }
          });
        } else if (data is List) {
          // Trường hợp API trả về List
          for (int i = 0; i < data.length; i++) {
            final episodeData = data[i];
            if (episodeData is Map<String, dynamic>) {
              final episodeId = episodeData['Id']?.toString() ?? i.toString();
              episodes.add(Episode.fromJson(episodeData, episodeId));
            }
          }
        } else if (data is Map<String, dynamic> && data.containsKey('Id')) {
          // Trường hợp API trả về một episode duy nhất
          final episodeId = data['Id']?.toString() ?? '0';
          episodes.add(Episode.fromJson(data, episodeId));
        }

        // Sắp xếp theo PublishedDate (mới nhất trước)
        episodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));

        return episodes;
      } else {
        throw Exception('Failed to load category data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching category data: $e');
    }
  }
}
