# Debug Home Page Loading Issue - "Unexpected null value"

## Vấn đề đã phát hiện và sửa

### 1. **Null Value Handling trong Episode.fromJson()** ❌➡️✅
**Vấn đề**: 
- JSON data có thể chứa null values
- `DateTime.parse()` gặp null hoặc invalid date
- Không có null safety cho các field

**Giải pháp**:
```dart
// Trước (SAI):
publishedDate: DateTime.parse(json['PublishedDate'] ?? DateTime.now().toIso8601String()),

// Sau (ĐÚNG):
publishedDate: _parseDate(json['PublishedDate']),

// Thêm method _parseDate an toàn:
static DateTime _parseDate(dynamic dateValue) {
  if (dateValue == null) return DateTime.now();
  try {
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    } else if (dateValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    } else {
      return DateTime.now();
    }
  } catch (e) {
    print('Error parsing date: $dateValue, error: $e');
    return DateTime.now();
  }
}
```

### 2. **String Conversion Safety** ❌➡️✅
**Vấn đề**: JSON values có thể không phải string

**Giải pháp**:
```dart
// Trước (SAI):
actor: json['Actor'] ?? '',

// Sau (ĐÚNG):
actor: json['Actor']?.toString() ?? '',
```

### 3. **FirebaseService Error Handling** ❌➡️✅
**Vấn đề**: 
- Không có try-catch cho từng episode
- Không kiểm tra episodeId có empty không
- Không skip episodes bị lỗi

**Giải pháp**:
```dart
for (final episodeData in categoryData) {
  if (episodeData is Map<String, dynamic>) {
    try {
      final episodeId = episodeData['Id']?.toString() ?? '';
      if (episodeId.isNotEmpty) {
        episodes.add(Episode.fromJson(episodeData, episodeId));
      }
    } catch (e) {
      print('Error parsing episode: $e');
      // Skip episode này và tiếp tục
    }
  }
}
```

### 4. **Debug Logging** ❌➡️✅
**Vấn đề**: Không có logs để debug

**Giải pháp**:
```dart
print('Loading home page data...');
final categories = await _firebaseService.getHomePageData();
print('Loaded ${categories.length} categories');
```

## Các thay đổi đã thực hiện

### 1. **Episode Model (`lib/models/episode.dart`)**
- ✅ Thêm `_parseDate()` method an toàn
- ✅ Sử dụng `?.toString()` cho tất cả string fields
- ✅ Try-catch cho date parsing
- ✅ Fallback values cho null data

### 2. **FirebaseService (`lib/services/firebase_service.dart`)**
- ✅ Try-catch cho từng episode parsing
- ✅ Kiểm tra episodeId không empty
- ✅ Skip episodes bị lỗi thay vì crash
- ✅ Chỉ add categories có episodes

### 3. **HomePage (`lib/screens/home_page.dart`)**
- ✅ Thêm debug logs
- ✅ Better error handling
- ✅ Clear error messages

## Debug Steps

### 1. **Kiểm tra Console Logs**
```bash
flutter run --debug
```
Tìm các log:
- "Loading home page data..."
- "Loaded X categories"
- "Error parsing episode: ..."
- "Error parsing date: ..."

### 2. **Test Data Loading**
1. **Check network connection**
2. **Verify Firebase URL accessible**
3. **Check JSON structure**
4. **Monitor error logs**

### 3. **Common Issues**
- **Network timeout**: Check internet connection
- **Invalid JSON**: Check Firebase data structure
- **Null values**: Now handled gracefully
- **Date parsing**: Now has fallbacks

## Expected Behavior

### ✅ **Success Case**
```
Loading home page data...
Loaded 3 categories
[Home page displays with data]
```

### ❌ **Error Case (Before Fix)**
```
Unexpected null value.
Unexpected null value.
[App crashes or shows blank screen]
```

### ✅ **Error Case (After Fix)**
```
Loading home page data...
Error parsing episode: [specific error]
Error parsing date: [specific error]
Loaded 2 categories
[Home page displays with available data]
```

## Troubleshooting

### 1. **Still getting null errors**
- Check if Firebase data structure changed
- Verify all required fields exist
- Check network connectivity

### 2. **No data loading**
- Check Firebase URL
- Verify network permissions
- Check console for HTTP errors

### 3. **Partial data loading**
- Some episodes might be skipped due to errors
- Check logs for specific parsing errors
- Verify episode data structure

## Test Cases

### ✅ **Valid Data**
- All episodes load successfully
- No null value errors
- Home page displays properly

### ✅ **Invalid Data**
- Episodes with null values are handled
- Invalid dates use fallback
- App doesn't crash

### ✅ **Network Issues**
- Error message displayed
- Retry option available
- Graceful degradation

## Monitoring

### Key Metrics:
- **Data load success rate**: Should be > 90%
- **Error handling**: No crashes on null values
- **Performance**: Load time < 3 seconds
- **User experience**: Smooth loading with feedback

## Next Steps

1. **Monitor logs** for any remaining issues
2. **Test with different data** scenarios
3. **Add retry mechanism** if needed
4. **Optimize loading** performance

Nếu vẫn còn vấn đề, hãy check console logs và cho tôi biết thông báo lỗi cụ thể!

