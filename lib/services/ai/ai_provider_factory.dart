import 'package:flutter/foundation.dart';
import 'ai_provider.dart';
import 'cloud_ai_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';
import 'exceptions.dart';
import '../../config/ai_config.dart';

/// Factory for creating AI providers with fallback logic
class AIProviderFactory {
  static CloudAIProvider? _cloudProvider;
  static AIProvider? _primaryProvider;
  static AIProvider? _backupProvider;

  static CloudAIProvider _createCloudProvider() {
    return CloudAIProvider();
  }

  /// Create primary provider (Gemini) — local dev only when [AIConfig.useCloudAI] is false
  static AIProvider _createPrimaryProvider() {
    try {
      // ignore: deprecated_member_use_from_same_package
      return GeminiProvider();
    } catch (e) {
      debugPrint('Failed to create Gemini provider: $e');
      throw AIException('Failed to initialize primary AI provider', e);
    }
  }

  /// Create backup provider (OpenAI) — local dev only
  static AIProvider _createBackupProvider() {
    try {
      // ignore: deprecated_member_use_from_same_package
      return OpenAIProvider();
    } catch (e) {
      debugPrint('Failed to create OpenAI provider: $e');
      throw AIException('Failed to initialize backup AI provider', e);
    }
  }

  static CloudAIProvider getCloudProvider() {
    _cloudProvider ??= _createCloudProvider();
    return _cloudProvider!;
  }

  /// Get primary provider (lazy initialization)
  static AIProvider getPrimaryProvider() {
    if (AIConfig.effectiveUseCloudAI) {
      return getCloudProvider();
    }
    _primaryProvider ??= _createPrimaryProvider();
    return _primaryProvider!;
  }

  /// Get backup provider (lazy initialization)
  static AIProvider getBackupProvider() {
    if (AIConfig.effectiveUseCloudAI) {
      return getCloudProvider();
    }
    _backupProvider ??= _createBackupProvider();
    return _backupProvider!;
  }

  /// Create provider with automatic fallback
  static Future<AIProvider> createProviderWithFallback() async {
    if (AIConfig.effectiveUseCloudAI) {
      debugPrint('✅ Using Cloud AI provider (Firebase Function)');
      return getCloudProvider();
    }

    if (kIsWeb) {
      throw AIException(
        'Tính năng AI chưa hỗ trợ trên trình duyệt. Vui lòng dùng app Android hoặc iOS.',
      );
    }

    debugPrint('🔄 AIProviderFactory: Creating provider with fallback...');

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
    if (AIConfig.effectiveUseCloudAI) {
      return getCloudProvider();
    }
    switch (type) {
      case AIProviderType.gemini:
        return getPrimaryProvider();
      case AIProviderType.openai:
        return getBackupProvider();
    }
  }

  /// Reset providers (useful for testing or re-initialization)
  static void reset() {
    _cloudProvider = null;
    _primaryProvider = null;
    _backupProvider = null;
  }
}
