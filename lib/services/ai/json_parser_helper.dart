import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Helper class for parsing JSON from AI responses
/// Handles various formats: markdown code blocks, text before/after JSON, etc.
class JsonParserHelper {
  /// Extract and parse JSON object from response
  static Map<String, dynamic> parseJsonObject(String response) {
    try {
      // Step 1: Try to find JSON in markdown code blocks
      final markdownJsonMatch = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(response);
      if (markdownJsonMatch != null) {
        final jsonStr = markdownJsonMatch.group(1)!.trim();
        return json.decode(jsonStr) as Map<String, dynamic>;
      }
      
      // Step 2: Try to find JSON object with balanced braces
      final jsonMatch = _extractBalancedJson(response, '{', '}');
      if (jsonMatch != null) {
        return json.decode(jsonMatch) as Map<String, dynamic>;
      }
      
      // Step 3: Try parsing entire response
      return json.decode(response.trim()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON parsing error: $e');
      debugPrint('Response: $response');
      rethrow;
    }
  }
  
  /// Extract and parse JSON array from response
  static List<Map<String, dynamic>> parseJsonArray(String response) {
    try {
      // Step 1: Try to find JSON in markdown code blocks
      final markdownJsonMatch = RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```').firstMatch(response);
      if (markdownJsonMatch != null) {
        final jsonStr = markdownJsonMatch.group(1)!.trim();
        final List<dynamic> parsed = json.decode(jsonStr);
        return parsed.cast<Map<String, dynamic>>();
      }
      
      // Step 2: Try to find JSON array with balanced brackets
      final jsonMatch = _extractBalancedJson(response, '[', ']');
      if (jsonMatch != null) {
        final List<dynamic> parsed = json.decode(jsonMatch);
        return parsed.cast<Map<String, dynamic>>();
      }
      
      // Step 3: Try parsing entire response
      final List<dynamic> parsed = json.decode(response.trim());
      return parsed.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('JSON array parsing error: $e');
      debugPrint('Response: $response');
      rethrow;
    }
  }
  
  /// Extract JSON with balanced brackets/braces
  static String? _extractBalancedJson(String text, String openChar, String closeChar) {
    int startIndex = text.indexOf(openChar);
    if (startIndex == -1) return null;
    
    int depth = 0;
    int endIndex = startIndex;
    
    for (int i = startIndex; i < text.length; i++) {
      if (text[i] == openChar) {
        depth++;
      } else if (text[i] == closeChar) {
        depth--;
        if (depth == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }
    
    if (depth == 0 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex);
    }
    
    return null;
  }
  
  /// Clean JSON string by removing common issues
  static String cleanJsonString(String jsonStr) {
    // Remove markdown code blocks if any
    jsonStr = jsonStr.replaceAll(RegExp(r'```(?:json)?\s*'), '');
    jsonStr = jsonStr.replaceAll('```', '');
    
    // Remove leading/trailing whitespace
    jsonStr = jsonStr.trim();
    
    // Fix common escape issues
    jsonStr = jsonStr.replaceAll('\\n', '\n');
    jsonStr = jsonStr.replaceAll('\\"', '"');
    
    return jsonStr;
  }
}

