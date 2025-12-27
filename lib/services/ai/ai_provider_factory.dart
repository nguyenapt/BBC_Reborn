import 'package:flutter/foundation.dart';
import 'ai_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';
import 'exceptions.dart';
import '../../config/ai_config.dart';

/// Factory for creating AI providers with fallback logic
class AIProviderFactory {
  static AIProvider? _primaryProvider;
  static AIProvider? _backupProvider;
  
  /// Create primary provider (Gemini)
  static AIProvider _createPrimaryProvider() {
    try {
      return GeminiProvider();
    } catch (e) {
      debugPrint('Failed to create Gemini provider: $e');
      throw AIException('Failed to initialize primary AI provider', e);
    }
  }
  
  /// Create backup provider (OpenAI)
  static AIProvider _createBackupProvider() {
    try {
      return OpenAIProvider();
    } catch (e) {
      debugPrint('Failed to create OpenAI provider: $e');
      throw AIException('Failed to initialize backup AI provider', e);
    }
  }
  
  /// Get primary provider (lazy initialization)
  static AIProvider getPrimaryProvider() {
    _primaryProvider ??= _createPrimaryProvider();
    return _primaryProvider!;
  }
  
  /// Get backup provider (lazy initialization)
  static AIProvider getBackupProvider() {
    _backupProvider ??= _createBackupProvider();
    return _backupProvider!;
  }
  
  /// Create provider with automatic fallback
  /// Tries primary first, falls back to backup if primary fails
  static Future<AIProvider> createProviderWithFallback() async {
    debugPrint('🔄 AIProviderFactory: Creating provider with fallback...');
    
    // Try primary provider first
    try {
      debugPrint('📱 Trying primary provider (Gemini)...');
      final primary = getPrimaryProvider();
      final isAvailable = await primary.isAvailable();
      debugPrint('📱 Primary provider available: $isAvailable');
      if (isAvailable) {
        debugPrint('✅ Using primary provider (Gemini)');
        return primary;
      } else {
        debugPrint('⚠️ Primary provider not available');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Primary provider error: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
    
    // Fallback to backup provider
    try {
      debugPrint('📱 Trying backup provider (OpenAI)...');
      final backup = getBackupProvider();
      final isAvailable = await backup.isAvailable();
      debugPrint('📱 Backup provider available: $isAvailable');
      if (isAvailable) {
        debugPrint('✅ Using backup AI provider (OpenAI)');
        return backup;
      } else {
        debugPrint('⚠️ Backup provider not available');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Backup provider error: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
    
    debugPrint('❌ No AI provider available - both primary and backup failed');
    throw AIException('No AI provider available');
  }
  
  /// Get specific provider by type
  static AIProvider getProvider(AIProviderType type) {
    switch (type) {
      case AIProviderType.gemini:
        return getPrimaryProvider();
      case AIProviderType.openai:
        return getBackupProvider();
    }
  }
  
  /// Reset providers (useful for testing or re-initialization)
  static void reset() {
    _primaryProvider = null;
    _backupProvider = null;
  }
}

