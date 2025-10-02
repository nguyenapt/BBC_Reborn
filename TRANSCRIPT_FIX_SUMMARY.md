# Transcript Fix Summary

## Vấn đề
Episode REE với ID `396af213-8beb-4214-877c-80949d8af04b` hiển thị "no transcript available" mặc dù có dữ liệu `TranscriptHtml` trong API.

## Nguyên nhân
1. **Regex pattern không đúng**: Pattern cũ `r'\[(\d+)\]([^\n]+)\n([^\[]+)\[(\d+)\]'` không khớp với format thực tế của API
2. **API format khác**: API trả về format `[start]Speaker Text[end]` thay vì `[start]Speaker\nText[end]`
3. **Firebase service parsing**: Không xử lý trường hợp API trả về một episode duy nhất

## Giải pháp

### 1. Sửa Regex Pattern
**File**: `lib/models/transcript_line.dart`

**Trước**:
```dart
RegExp pattern = RegExp(r'\[(\d+)\]([^\n]+)\n([^\[]+)\[(\d+)\]');
```

**Sau**:
```dart
RegExp pattern = RegExp(r'\[(\d+)\]([^[]+?)\[(\d+)\]');
```

### 2. Cập nhật Logic Parse
- Sử dụng `allMatches()` thay vì split theo dòng trắng
- Tách speaker và text bằng cách split theo space
- Speaker là từ đầu tiên, phần còn lại là text

### 3. Sửa Firebase Service
**File**: `lib/services/firebase_service.dart`

Thêm xử lý cho trường hợp API trả về một episode duy nhất:
```dart
} else if (data is Map<String, dynamic> && data.containsKey('Id')) {
  // Trường hợp API trả về một episode duy nhất (như REE/2025/0.json)
  final episodeId = data['Id']?.toString() ?? '0';
  episodes.add(Episode.fromJson(data, episodeId));
}
```

## Kết quả
✅ Episode REE với ID `396af213-8beb-4214-877c-80949d8af04b` giờ đây hiển thị transcript đúng cách
✅ Parse được 5+ dòng transcript với speaker và timing chính xác
✅ Highlight và auto scroll hoạt động bình thường
✅ Vocabulary cũng hiển thị đúng với 2 từ vựng

## Test Data
API: `https://bbc-listening-english.firebaseio.com/REE/2025/0.json`
- TranscriptHtml: Có dữ liệu đầy đủ
- Vocabularies: 2 items (shopping list, staple)
- Vocabulary: Fallback string format

## Files Modified
- `lib/models/transcript_line.dart` - Sửa regex và logic parse
- `lib/services/firebase_service.dart` - Thêm xử lý single episode
- `lib/widgets/transcript_slide.dart` - Xóa debug log




