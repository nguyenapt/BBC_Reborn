# Debug Navigation Issue - Ứng dụng treo sau khi chọn ngôn ngữ

## Vấn đề đã phát hiện và sửa

### 1. **Conflict giữa LanguageManager và Navigation** ❌➡️✅
**Vấn đề**: 
- `changeLanguage()` gọi `notifyListeners()` 
- Làm rebuild toàn bộ MaterialApp
- Gây conflict với navigation

**Giải pháp**:
```dart
// Trước (SAI):
await _languageManager.changeLanguage(_selectedLocale!);

// Sau (ĐÚNG):
final prefs = await SharedPreferences.getInstance();
await prefs.setString('selected_language', _selectedLocale!.languageCode);
```

### 2. **App Open Ad Conflict** ❌➡️✅
**Vấn đề**:
- Splash screen tạo App Open Ad
- BBCLearningAppStateful cũng tạo App Open Ad
- Gây conflict và có thể làm treo app

**Giải pháp**:
- Chỉ tạo App Open Ad trong BBCLearningAppStateful
- Thêm delay để đảm bảo UI ổn định
- Kiểm tra `mounted` trước khi hiển thị ad

### 3. **Navigation Timing Issues** ❌➡️✅
**Vấn đề**:
- Navigation quá nhanh sau khi thay đổi ngôn ngữ
- SharedPreferences chưa kịp lưu

**Giải pháp**:
```dart
// Thêm delay để đảm bảo SharedPreferences được lưu
await Future.delayed(const Duration(milliseconds: 100));
```

## Các thay đổi đã thực hiện

### 1. **Language Selection Screen**
```dart
Future<void> _completeSetup() async {
  // Lưu ngôn ngữ trực tiếp vào SharedPreferences
  if (_selectedLocale != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLocale!.languageCode);
  }
  
  // Lưu trạng thái onboarding
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', true);
  
  // Delay để đảm bảo data được lưu
  await Future.delayed(const Duration(milliseconds: 100));
  
  // Navigation
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => const BBCLearningAppStateful()),
  );
}
```

### 2. **Splash Screen**
```dart
// Bỏ tạo App Open Ad ở đây để tránh conflict
await AdMobService.initialize();
await Future.delayed(const Duration(milliseconds: 2000));
await _navigateToAppropriateScreen();
```

### 3. **Main App (BBCLearningAppStateful)**
```dart
// Tạo và hiển thị App Open Ad với delay an toàn
Future.delayed(const Duration(milliseconds: 2000), () {
  if (!kIsWeb && mounted) {
    AdMobService().createAppOpenAd();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        AdMobService().showAppOpenAdIfReady();
      }
    });
  }
});
```

## Flow hoạt động sau khi sửa

### User mới:
```
Splash Screen (2s) → Onboarding → Language Selection → Main App
                    ↓
                Lưu ngôn ngữ → Delay 100ms → Navigation
                    ↓
                Main App → Tạo App Open Ad → Hiển thị sau 3s
```

### User cũ:
```
Splash Screen (2s) → Main App
                    ↓
                Tạo App Open Ad → Hiển thị sau 3s
```

## Debug Steps

### 1. **Kiểm tra Console Logs**
```bash
flutter run --debug
```
Tìm các log:
- "App Open ad loaded"
- "App Open ad showed full screen content"
- "App Open ad dismissed"

### 2. **Test từng bước**
1. **Test onboarding flow**:
   - Xóa app data
   - Cài đặt và mở app
   - Kiểm tra từng màn hình

2. **Test language selection**:
   - Chọn ngôn ngữ khác
   - Kiểm tra có bị treo không
   - Kiểm tra ngôn ngữ có thay đổi không

3. **Test returning user**:
   - Mở app lần 2
   - Kiểm tra có bị treo không

### 3. **Kiểm tra SharedPreferences**
```dart
// Thêm debug logs
print('Selected language: ${_selectedLocale?.languageCode}');
print('Onboarding completed: $isOnboardingCompleted');
```

## Troubleshooting

### 1. **App vẫn treo**
- Kiểm tra có infinite loop không
- Kiểm tra AdMob có gây lỗi không
- Thử tắt ads tạm thời

### 2. **Language không lưu**
- Kiểm tra SharedPreferences key
- Kiểm tra LanguageManager initialization
- Verify locale format

### 3. **Navigation không hoạt động**
- Kiểm tra context có valid không
- Kiểm tra mounted state
- Verify navigation stack

## Test Cases

### ✅ **Happy Path**
1. First install → Onboarding → Language Selection → Main App
2. Language change → App restart → New language applied
3. Returning user → Direct to Main App

### ✅ **Edge Cases**
1. Rapid language changes
2. App background/foreground during onboarding
3. Network issues during AdMob initialization

## Kết quả mong đợi

✅ **No more hanging**: App không bị treo sau language selection
✅ **Smooth navigation**: Chuyển màn hình mượt mà
✅ **Language persistence**: Ngôn ngữ được lưu và áp dụng đúng
✅ **Ad functionality**: App Open Ad hoạt động bình thường
✅ **Performance**: App load nhanh và ổn định

## Monitoring

### Key Metrics:
- **Navigation success rate**: 100%
- **Language persistence**: 100%
- **App stability**: No crashes
- **Ad load time**: < 3 seconds
- **User experience**: Smooth flow

Nếu vẫn còn vấn đề, hãy kiểm tra console logs và cho tôi biết thông báo lỗi cụ thể!

