import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/grammar.dart';

class GrammarService {
  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';
  static const String _grammarPath = 'HomePage/Grammar';

  /// Lấy danh sách tất cả grammars
  Future<List<Grammar>> getAllGrammars() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        print('API Response type: ${data.runtimeType}');
        print('API Response data: $data');
        
        final List<Grammar> grammars = [];

        if (data is List) {
          // Nếu API trả về List
          print('Processing List with ${data.length} items');
          for (var item in data) {
            if (item is Map<String, dynamic>) {
              try {
                grammars.add(Grammar.fromJson(item));
              } catch (e) {
                print('Error parsing grammar item: $e');
                print('Item data: $item');
              }
            }
          }
        } else if (data is Map<String, dynamic>) {
          // Nếu API trả về Map
          print('Processing Map with ${data.length} keys');
          data.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              try {
                grammars.add(Grammar.fromJson(value));
              } catch (e) {
                print('Error parsing grammar item: $e');
                print('Item data: $value');
              }
            }
          });
        } else {
          print('Unexpected data type: ${data.runtimeType}');
          // Trả về danh sách rỗng nếu không thể parse
          return [];
        }

        // Sắp xếp theo SortOrder
        grammars.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        print('Successfully parsed ${grammars.length} grammars');
        
        // Log thông tin chi tiết
        for (var grammar in grammars) {
          print('Grammar: ${grammar.name} (SortOrder: ${grammar.sortOrder}, ${grammar.parts.length} parts)');
          for (var part in grammar.parts) {
            print('  - ${part.name} (Order: ${part.sortOrder})');
          }
        }
        
        return grammars;
      } else {
        throw Exception('Failed to load grammars: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching grammars: $e');
    }
  }

  /// Mock data để test UI (backup)
  List<Grammar> _getMockGrammars() {
    return [
      Grammar(
        id: 'mock-1',
        name: 'Present Simple',
        sortOrder: 0,
        parts: [
          GrammarPart(
            id: 'mock-part-1',
            name: 'Cách sử dụng',
            theory: '<h3>Present Simple được sử dụng để:</h3><ul><li>Diễn tả thói quen hàng ngày</li><li>Diễn tả sự thật hiển nhiên</li><li>Diễn tả lịch trình cố định</li></ul>',
            description: '<p>Present Simple là thì đơn giản nhất trong tiếng Anh, thường được sử dụng với các trạng từ chỉ tần suất như <strong>always, usually, often, sometimes, never</strong>.</p>',
            sortOrder: 0,
          ),
          GrammarPart(
            id: 'mock-part-2',
            name: 'Cấu trúc',
            theory: '<h3>Công thức:</h3><ul><li><strong>Khẳng định:</strong> S + V(s/es) + O</li><li><strong>Phủ định:</strong> S + do/does + not + V + O</li><li><strong>Nghi vấn:</strong> Do/Does + S + V + O?</li></ul>',
            description: '<p>Với chủ ngữ số ít (he, she, it), động từ thêm <strong>-s</strong> hoặc <strong>-es</strong>. Với chủ ngữ số nhiều, giữ nguyên động từ.</p>',
            sortOrder: 1,
          ),
        ],
      ),
    ];
  }

  /// Lấy grammar theo ID
  Future<Grammar?> getGrammarById(String grammarId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath/$grammarId.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Grammar.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching grammar by ID: $e');
      return null;
    }
  }

  /// Test API để xem cấu trúc dữ liệu
  Future<void> testApi() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath.json'),
        headers: {'Accept': 'application/json'},
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        print('Parsed Data Type: ${data.runtimeType}');
        print('Parsed Data: $data');
      }
    } catch (e) {
      print('Test API Error: $e');
    }
  }
}
