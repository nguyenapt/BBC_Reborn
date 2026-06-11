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

  /// Heuristic cho roleplay: label có vẻ là tên người / host, không phải chú thích (Note, Example…).
  /// Parser chỉ lấy [từ đầu] làm speaker nên các dòng kiểu "Note: ..." / "Example ..." bị nhầm thành speaker.
  static bool isLikelyPersonSpeakerLabel(String speaker) {
    var s = speaker.trim();
    if (s.isEmpty) return false;
    if (s.startsWith('(') || s.startsWith('[')) return false;
    s = s.replaceAll(RegExp(r'[:;,.]+$'), '').trim();
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    if (RegExp(r'^\d+$').hasMatch(lower)) return false;
    const block = <String>{
      'note',
      'notes',
      'example',
      'examples',
      'eg',
      'eg.',
      'e.g',
      'e.g.',
      'ex',
      'ex.',
      'see',
      'cf',
      'cf.',
      'audio',
      'sound',
      'sfx',
      'music',
      'pause',
      'break',
      'intro',
      'outro',
      'host',
      'narrator',
      'voice',
      'voiceover',
      'vo',
      'read',
      'reading',
      'quote',
      'quotation',
      'caption',
      'translation',
      'transcript',
      'section',
      'part',
      'chapter',
      'scene',
      'footnote',
      'reference',
      'source',
      'credits',
      'advertisement',
      'advert',
      'ad',
      'speaker',
      'speakers',
      'presenter',
      'reporter',
      'interviewer',
      'interviewee',
      'guest',
      'studio',
      'field',
      'live',
      'recording',
      'clip',
      'extract',
      '-',
      '--',
      '---',
      '----',
      '-----',
    };
    if (block.contains(lower)) return false;
    if (lower.startsWith('note') && lower.length <= 6) {
      return false;
    }
    if (lower.startsWith('example')) return false;
    return true;
  }

  /// VOA: tìm `:` trong [maxWords] từ đầu để tách speaker / text.
  static ({String speaker, String text, bool hasSpeakerMarker}) splitSpeakerByColon(
    String line, {
    int maxWords = 5,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return (speaker: '', text: '', hasSpeakerMarker: false);
    }
    if (!trimmed.contains(':')) {
      return (speaker: '', text: trimmed, hasSpeakerMarker: false);
    }

    final colonIndex = trimmed.indexOf(':');
    final lastCharOfNthWord = _lastCharIndexOfNthWord(trimmed, maxWords);
    if (colonIndex > lastCharOfNthWord) {
      return (speaker: '', text: trimmed, hasSpeakerMarker: false);
    }

    final speaker = trimmed.substring(0, colonIndex).trim();
    final text = trimmed.substring(colonIndex + 1).trim();
    return (speaker: speaker, text: text, hasSpeakerMarker: true);
  }

  static int _lastCharIndexOfNthWord(String s, int n) {
    if (n <= 0) return -1;
    int wordCount = 0;
    int lastChar = -1;
    bool inWord = false;

    for (int i = 0; i < s.length; i++) {
      final isSpace = s[i].trim().isEmpty;
      if (!isSpace) {
        if (!inWord) {
          wordCount++;
          inWord = true;
        }
        if (wordCount <= n) {
          lastChar = i;
        }
      } else {
        inWord = false;
      }
      if (wordCount >= n) break;
    }
    return lastChar;
  }

  /// VOA plain transcript: `Name: dialogue` hoặc `Name:` rồi dòng tiếp theo.
  static List<TranscriptLine> parseVoaPlainTranscript(String transcript) {
    if (transcript.trim().isEmpty) return [];

    final rawLines = transcript.split('\n');
    final lines = <TranscriptLine>[];
    String? activeSpeaker;

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final split = splitSpeakerByColon(trimmed);
      if (split.hasSpeakerMarker) {
        if (split.text.isEmpty) {
          activeSpeaker = split.speaker;
          continue;
        }
        activeSpeaker = null;
        lines.add(TranscriptLine(
          startTime: 0,
          endTime: 0,
          speaker: split.speaker,
          text: split.text,
        ));
        continue;
      }

      final speaker = activeSpeaker ?? '';
      lines.add(TranscriptLine(
        startTime: 0,
        endTime: 0,
        speaker: speaker,
        text: split.text,
      ));
    }

    return lines;
  }

  /// Parse transcriptHtml thành danh sách TranscriptLine
  static List<TranscriptLine> parseTranscriptHtml(String? transcriptHtml) {
    if (transcriptHtml == null || transcriptHtml.isEmpty) {
      return [];
    }

    final List<TranscriptLine> lines = [];

    // Tìm tất cả pattern [start]Text[end] trong toàn bộ string
    final RegExp pattern = RegExp(r'\[(\d+)\]([^[]+?)\[(\d+)\]');
    final Iterable<Match> matches = pattern.allMatches(transcriptHtml);

    for (final match in matches) {
      final int startTime = int.tryParse(match.group(1) ?? '0') ?? 0;
      String content = match.group(2)?.trim() ?? '';
      final int endTime = int.tryParse(match.group(3) ?? '0') ?? 0;

      if (content.isEmpty) continue;

      content = _stripHtmlTags(content);
      final split = splitSpeakerByColon(content);
      if (split.text.isEmpty && !split.hasSpeakerMarker) continue;

      lines.add(TranscriptLine(
        startTime: startTime,
        endTime: endTime,
        speaker: split.hasSpeakerMarker ? split.speaker : '',
        text: split.hasSpeakerMarker ? split.text : split.text,
      ));
    }

    return lines;
  }

  /// Entry point: transcriptHtml ưu tiên, fallback plain VOA.
  static List<TranscriptLine> parseFromTranscript({
    String? transcriptHtml,
    String? transcript,
  }) {
    if (transcriptHtml != null && transcriptHtml.trim().isNotEmpty) {
      final fromHtml = parseTranscriptHtml(transcriptHtml);
      if (fromHtml.isNotEmpty) {
        final hasTiming = fromHtml.any(
          (line) => line.startTime != 0 || line.endTime != 0,
        );
        if (hasTiming) return fromHtml;

        final plainFromHtml = _stripHtmlTags(transcriptHtml)
            .replaceAll(RegExp(r'\[\d+\]'), '\n')
            .replaceAll(RegExp(r'\n+'), '\n');
        final voa = parseVoaPlainTranscript(plainFromHtml);
        if (voa.isNotEmpty) return voa;
        return fromHtml;
      }
    }

    if (transcript != null && transcript.trim().isNotEmpty) {
      return parseVoaPlainTranscript(transcript);
    }
    return [];
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
