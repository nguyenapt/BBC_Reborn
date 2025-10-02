# Hướng dẫn Onboarding Flow

## Tổng quan
Ứng dụng BBC Learning English đã được tích hợp flow onboarding hoàn chỉnh cho user mới, bao gồm:

1. **Splash Screen** - Màn hình khởi động với logo và loading
2. **Onboarding Screens** - 3 màn hình giới thiệu ứng dụng
3. **Language Selection** - Màn hình chọn ngôn ngữ giao diện
4. **Double Back to Exit** - Tính năng nhấn back 2 lần để thoát

## Flow hoạt động

### 1. Splash Screen
- **Mục đích**: Hiển thị logo và loading khi khởi động app
- **Thời gian**: Tối thiểu 2 giây
- **Chức năng**: 
  - Khởi tạo AdMob service
  - Tạo App Open Ad
  - Kiểm tra trạng thái onboarding
  - Chuyển hướng phù hợp

### 2. Onboarding Screens (3 màn hình)
- **Màn hình 1**: Chào mừng và giới thiệu ứng dụng
- **Màn hình 2**: Tính năng học offline và di động
- **Màn hình 3**: Cá nhân hóa trải nghiệm
- **Tính năng**: 
  - Page indicators
  - Skip button
  - Smooth transitions
  - Responsive design

### 3. Language Selection Screen
- **Mục đích**: Cho phép user chọn ngôn ngữ giao diện
- **Ngôn ngữ hỗ trợ**: 9 ngôn ngữ (VI, EN, ZH, JA, KO, ES, PT, AR, RU)
- **Tính năng**:
  - UI đẹp mắt với flag icons
  - Native language names
  - Selection feedback
  - Auto-save preferences

### 4. Double Back to Exit
- **Mục đích**: Tránh thoát app vô tình
- **Cách hoạt động**: 
  - Nhấn back lần 1: Hiển thị snackbar "Nhấn Back lần nữa để thoát"
  - Nhấn back lần 2 trong 2 giây: Thoát app
  - Quá 2 giây: Reset counter

## Cấu trúc Files

### Files mới tạo:
- `lib/screens/splash_screen.dart` - Màn hình splash
- `lib/screens/onboarding_screen.dart` - 3 màn hình onboarding
- `lib/screens/language_selection_screen.dart` - Chọn ngôn ngữ
- `lib/utils/double_back_exit.dart` - Mixin cho double back exit

### Files đã sửa đổi:
- `lib/main.dart` - Tích hợp splash screen và double back exit

## Logic hoạt động

### First-time user:
```
Splash Screen → Onboarding Screens → Language Selection → Home Page
```

### Returning user:
```
Splash Screen → Home Page (với App Open Ad)
```

### Onboarding completion check:
```dart
final prefs = await SharedPreferences.getInstance();
final isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
```

## Tính năng nổi bật

### 1. Smooth Animations
- Fade và scale animations cho logo
- Page transitions mượt mà
- Loading indicators

### 2. User Experience
- Skip option cho onboarding
- Visual feedback cho selections
- Responsive design
- Intuitive navigation

### 3. Performance
- Lazy loading
- Efficient state management
- Memory optimization

### 4. Accessibility
- Clear visual indicators
- Intuitive button placement
- Consistent design language

## Customization

### Thay đổi nội dung onboarding:
Chỉnh sửa `_onboardingData` trong `onboarding_screen.dart`:

```dart
final List<OnboardingData> _onboardingData = [
  OnboardingData(
    title: 'Your Title',
    description: 'Your Description',
    image: '🎯',
    color: Colors.blue,
  ),
  // Thêm màn hình khác...
];
```

### Thay đổi thời gian splash:
Chỉnh sửa delay trong `splash_screen.dart`:

```dart
await Future.delayed(const Duration(milliseconds: 2000)); // 2 giây
```

### Thêm ngôn ngữ mới:
1. Thêm vào `supportedLocales` trong `language_manager.dart`
2. Thêm vào `_languages` trong `language_selection_screen.dart`
3. Tạo file localization tương ứng

## Testing

### Test scenarios:
1. **First install**: Xóa app → Cài đặt → Kiểm tra flow hoàn chỉnh
2. **Returning user**: Mở app lần 2 → Chỉ thấy splash → home
3. **Language change**: Thay đổi ngôn ngữ → Kiểm tra UI update
4. **Double back**: Test double back to exit
5. **Skip onboarding**: Test skip button

### Debug mode:
```bash
flutter run --debug
```

### Release mode:
```bash
flutter run --release
```

## Troubleshooting

### 1. Onboarding không hiển thị
- Kiểm tra SharedPreferences
- Xóa app data và cài lại
- Check `onboarding_completed` flag

### 2. Language không lưu
- Kiểm tra `changeLanguage` method
- Verify SharedPreferences permissions
- Check LanguageManager initialization

### 3. Double back không hoạt động
- Kiểm tra PopScope implementation
- Verify mixin usage
- Test trên thiết bị thật

### 4. Performance issues
- Check animation durations
- Monitor memory usage
- Optimize image loading

## Best Practices

1. **Keep onboarding short**: 3-4 màn hình tối đa
2. **Clear value proposition**: Mỗi màn hình nên có 1 message rõ ràng
3. **Skip option**: Luôn cho phép skip
4. **Visual consistency**: Sử dụng design system thống nhất
5. **Test thoroughly**: Test trên nhiều thiết bị và kích thước màn hình

