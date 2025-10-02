import 'package:flutter/material.dart';
import '../models/vocabulary_item.dart';
import '../services/storage_service.dart';

class VocabularyService extends ChangeNotifier {
  static final VocabularyService _instance = VocabularyService._internal();
  factory VocabularyService() => _instance;
  VocabularyService._internal();

  final StorageService _storageService = StorageService();
  List<VocabularyItem> _savedVocabularies = [];

  List<VocabularyItem> get savedVocabularies => _savedVocabularies;

  /// Initialize service và load saved vocabularies
  Future<void> initialize() async {
    await _loadSavedVocabularies();
  }

  /// Load saved vocabularies từ storage
  Future<void> _loadSavedVocabularies() async {
    try {
      final savedData = await _storageService.getSavedVocabularyItems();
      _savedVocabularies = savedData;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved vocabularies: $e');
    }
  }

  /// Save vocabulary item
  Future<bool> saveVocabulary(VocabularyItem item) async {
    try {
      // Kiểm tra xem đã tồn tại chưa
      if (_savedVocabularies.any((v) => v.vocab == item.vocab)) {
        return false; // Đã tồn tại
      }

      _savedVocabularies.add(item);
      await _storageService.saveVocabularyItems(_savedVocabularies);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving vocabulary: $e');
      return false;
    }
  }

  /// Remove vocabulary item
  Future<bool> removeVocabulary(String vocab) async {
    try {
      _savedVocabularies.removeWhere((v) => v.vocab == vocab);
      await _storageService.saveVocabularyItems(_savedVocabularies);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing vocabulary: $e');
      return false;
    }
  }

  /// Check if vocabulary is saved
  bool isVocabularySaved(String vocab) {
    return _savedVocabularies.any((v) => v.vocab == vocab);
  }

  /// Get saved vocabulary by vocab
  VocabularyItem? getSavedVocabulary(String vocab) {
    try {
      return _savedVocabularies.firstWhere((v) => v.vocab == vocab);
    } catch (e) {
      return null;
    }
  }
}
