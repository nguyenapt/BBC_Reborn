class TranscriptLine {
  final int startTime; // Thời gian bắt đầu (milliseconds)
  final int endTime;   // Thời gian kết thúc (milliseconds)
  final String speaker; // Tên người nói
  final String text;    // Nội dung text

  TranscriptLine({
    required this.startTime,
    required this.endTime,
    required this.speaker,
    required this.text,
  });

  // Parse transcriptHtml thành danh sách TranscriptLine
  static List<TranscriptLine> parseTranscriptHtml(String? transcriptHtml) {
    if (transcriptHtml == null || transcriptHtml.isEmpty) {
      return [];
    }

    List<TranscriptLine> lines = [];
    
    // Tìm tất cả pattern [start]Speaker Text[end] trong toàn bộ string
    RegExp pattern = RegExp(r'\[(\d+)\]([^[]+?)\[(\d+)\]');
    Iterable<Match> matches = pattern.allMatches(transcriptHtml);
    
    for (Match match in matches) {
      int startTime = int.tryParse(match.group(1) ?? '0') ?? 0;
      String content = match.group(2)?.trim() ?? '';
      int endTime = int.tryParse(match.group(3) ?? '0') ?? 0;
      
      if (content.isNotEmpty) {
        // Strip HTML tags từ content
        content = _stripHtmlTags(content);
        
        // Tách speaker và text (speaker là từ đầu tiên, phần còn lại là text)
        List<String> parts = content.split(' ');
        if (parts.length > 1) {
          String speaker = parts[0];
          String text = parts.sublist(1).join(' ');
          
          lines.add(TranscriptLine(
            startTime: startTime,
            endTime: endTime,
            speaker: speaker,
            text: text,
          ));
        }
      }
    }
    
    return lines;
  }

  // Xóa tất cả HTML tags khỏi text
  static String _stripHtmlTags(String htmlText) {
    // Regex để match tất cả HTML tags
    RegExp htmlTagRegex = RegExp(r'<[^>]*>');
    
    // Thay thế tất cả HTML tags bằng empty string
    String cleanText = htmlText.replaceAll(htmlTagRegex, '');
    
    // Xóa các HTML entities phổ biến
    cleanText = cleanText
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&apos;', "'");
    
    // Xóa multiple spaces và trim
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleanText;
  }

  // Kiểm tra xem thời gian hiện tại có nằm trong khoảng của line này không
  bool isActiveAt(int currentTimeMs) {
    return currentTimeMs >= startTime && currentTimeMs <= endTime;
  }

  // Kiểm tra xem thời gian hiện tại có vượt quá line này không
  bool isPassedAt(int currentTimeMs) {
    return currentTimeMs > endTime;
  }
}
