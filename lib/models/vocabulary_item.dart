class VocabularyItem {
  final String id;
  final String bbcEpisodeId;
  final String vocab;
  final String mean;

  VocabularyItem({
    required this.id,
    required this.bbcEpisodeId,
    required this.vocab,
    required this.mean,
  });

  // Parse từ field vocabularies (JSON array)
  static List<VocabularyItem> parseVocabularies(List<dynamic>? vocabularies) {
    if (vocabularies == null) return [];
    
    List<VocabularyItem> items = [];
    
    for (var item in vocabularies) {
      if (item is Map<String, dynamic>) {
        items.add(VocabularyItem(
          id: item['Id']?.toString() ?? '',
          bbcEpisodeId: item['BBCEpisodeId']?.toString() ?? '',
          vocab: item['Vocab']?.toString() ?? '',
          mean: item['Mean']?.toString() ?? '',
        ));
      }
    }
    
    return items;
  }

  // Parse từ field vocabulary (fallback string format)
  static List<VocabularyItem> parseVocabularyString(String? vocabulary) {
    if (vocabulary == null || vocabulary.isEmpty) return [];
    
    List<VocabularyItem> items = [];
    
    // Split theo \r\n
    List<String> lines = vocabulary.split('\r\n');
    
    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Split theo dấu :
      int colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        String vocab = line.substring(0, colonIndex).trim();
        String mean = line.substring(colonIndex + 1).trim();
        
        items.add(VocabularyItem(
          id: '', // Không có ID cho fallback
          bbcEpisodeId: '',
          vocab: vocab,
          mean: mean,
        ));
      }
    }
    
    return items;
  }

  // Parse từ cả hai nguồn (vocabularies ưu tiên, vocabulary làm fallback)
  static List<VocabularyItem> parseFromEpisode({
    List<dynamic>? vocabularies,
    String? vocabulary,
  }) {
    // Ưu tiên vocabularies trước
    if (vocabularies != null && vocabularies.isNotEmpty) {
      return parseVocabularies(vocabularies);
    }
    
    // Fallback về vocabulary
    return parseVocabularyString(vocabulary);
  }
}




