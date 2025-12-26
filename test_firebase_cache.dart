// Test script để kiểm tra Firebase cache
// Chạy trong Flutter app để test

import 'package:flutter/foundation.dart';
import 'lib/services/ai_firebase_cache_service.dart';
import 'lib/services/ai_cache_service.dart';

void testFirebaseCache() async {
  debugPrint('🧪 Testing Firebase Cache...');
  
  final firebaseCache = AIFirebaseCacheService();
  final cacheService = AICacheService();
  
  // Test data
  const testEpisodeId = 'test-episode-123';
  const testLanguageCode = 'vi';
  final testTranslations = {
    'Hello': 'Xin chào',
    'World': 'Thế giới',
    'Test': 'Kiểm tra',
  };
  
  try {
    // Test 1: Save to Firebase
    debugPrint('\n📝 Test 1: Saving to Firebase...');
    await firebaseCache.saveTranslation(
      testEpisodeId,
      testLanguageCode,
      testTranslations,
    );
    
    // Wait a bit
    await Future.delayed(const Duration(seconds: 2));
    
    // Test 2: Read from Firebase
    debugPrint('\n📖 Test 2: Reading from Firebase...');
    final cached = await firebaseCache.getTranslation(
      testEpisodeId,
      testLanguageCode,
    );
    
    if (cached != null) {
      debugPrint('✅ Successfully read from Firebase!');
      debugPrint('   Cached translations: $cached');
    } else {
      debugPrint('❌ Failed to read from Firebase');
    }
    
    // Test 3: Test through AICacheService
    debugPrint('\n🔄 Test 3: Testing through AICacheService...');
    await cacheService.saveTranslationToCache(
      testEpisodeId,
      testLanguageCode,
      testTranslations,
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    final cachedFromService = await cacheService.getTranslationFromCache(
      testEpisodeId,
      testLanguageCode,
    );
    
    if (cachedFromService != null) {
      debugPrint('✅ Successfully read through AICacheService!');
      debugPrint('   Cached translations: $cachedFromService');
    } else {
      debugPrint('❌ Failed to read through AICacheService');
    }
    
    debugPrint('\n✅ Test completed!');
  } catch (e, stackTrace) {
    debugPrint('❌ Test failed with error: $e');
    debugPrint('   Stack trace: $stackTrace');
  }
}

