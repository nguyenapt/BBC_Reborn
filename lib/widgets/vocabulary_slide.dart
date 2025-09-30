import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../services/storage_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

class VocabularySlide extends StatefulWidget {
  final Episode episode;

  const VocabularySlide({
    super.key,
    required this.episode,
  });

  @override
  State<VocabularySlide> createState() => _VocabularySlideState();
}

class _VocabularySlideState extends State<VocabularySlide> {
  final Set<String> _savedVocabularies = {};
  final StorageService _storageService = StorageService();
  final FirebaseStorageService _firebaseStorageService = FirebaseStorageService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedVocabularies();
  }

  @override
  Widget build(BuildContext context) {
    // Parse vocabulary từ episode
    final vocabularies = _parseVocabularies();
    
    if (vocabularies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Không có vocabulary cho episode này',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.library_books,
                color: CategoryColors.getCategoryColor(widget.episode.category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Vocabulary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CategoryColors.getCategoryColor(widget.episode.category),
                ),
              ),
              const Spacer(),
              Text(
                '${vocabularies.length} từ',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Vocabulary List
          Expanded(
            child: ListView.builder(
              itemCount: vocabularies.length,
              itemBuilder: (context, index) {
                final vocabulary = vocabularies[index];
                final isSaved = _savedVocabularies.contains(vocabulary);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        vocabulary,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => _toggleVocabulary(vocabulary),
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      onTap: () {
                        // TODO: Show vocabulary detail/definition
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tìm kiếm định nghĩa cho: $vocabulary'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Save All Button
          if (vocabularies.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _saveAllVocabularies,
                icon: const Icon(Icons.save),
                label: Text(
                  'Lưu tất cả vào Vocabulary cá nhân',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CategoryColors.getCategoryColor(widget.episode.category),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _parseVocabularies() {
    if (widget.episode.vocabulary == null || widget.episode.vocabulary!.isEmpty) {
      return [];
    }
    
    // Split by comma and clean up
    return widget.episode.vocabulary!
        .split(',')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Future<void> _loadSavedVocabularies() async {
    try {
      final savedVocabularies = await _storageService.getSavedVocabularies();
      setState(() {
        _savedVocabularies.addAll(savedVocabularies);
      });
    } catch (e) {
      debugPrint('Error loading saved vocabularies: $e');
    }
  }

  void _toggleVocabulary(String vocabulary) async {
    try {
      if (_savedVocabularies.contains(vocabulary)) {
        // Remove from storage
        await _storageService.removeVocabulary(vocabulary);
        // Only remove from Firebase if user is logged in
        if (_authService.isLoggedIn) {
          await _firebaseStorageService.removeVocabulary(_userService.userId, vocabulary);
        }
        
        setState(() {
          _savedVocabularies.remove(vocabulary);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "$vocabulary" khỏi vocabulary cá nhân'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to storage
        await _storageService.addVocabulary(vocabulary);
        // Only add to Firebase if user is logged in
        if (_authService.isLoggedIn) {
          await _firebaseStorageService.addVocabulary(_userService.userId, vocabulary);
        }
        
        setState(() {
          _savedVocabularies.add(vocabulary);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu "$vocabulary" vào vocabulary cá nhân'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling vocabulary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveAllVocabularies() async {
    try {
      final vocabularies = _parseVocabularies();
      
      // Save to storage
      for (final vocabulary in vocabularies) {
        await _storageService.addVocabulary(vocabulary);
        // Only add to Firebase if user is logged in
        if (_authService.isLoggedIn) {
          await _firebaseStorageService.addVocabulary(_userService.userId, vocabulary);
        }
      }
      
      setState(() {
        _savedVocabularies.addAll(vocabularies);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu ${vocabularies.length} từ vào vocabulary cá nhân'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error saving all vocabularies: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

