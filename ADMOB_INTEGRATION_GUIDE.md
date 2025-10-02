# Hướng dẫn tích hợp Google AdMob

## Tổng quan
Ứng dụng BBC Learning English đã được tích hợp Google AdMob với các tính năng sau:
- **Banner ads**: Hiển thị trên Home page và Categories screen
- **Interstitial ads**: Hiển thị khi người dùng rời khỏi Episode detail screen
- **App Open ads**: Hiển thị khi mở ứng dụng và khi resume từ background (với cooldown 4 giờ)

## Cấu hình đã thực hiện

### 1. Dependencies
- Đã thêm `google_mobile_ads: ^5.1.0` vào `pubspec.yaml`

### 2. Android Configuration
- **AndroidManifest.xml**: Thêm quyền INTERNET và ACCESS_NETWORK_STATE
- **AndroidManifest.xml**: Thêm AdMob App ID (test ID)
- **build.gradle.kts**: Thêm Google Play Services Ads dependency

### 3. iOS Configuration
- **Info.plist**: Thêm GADApplicationIdentifier (test ID)
- **Info.plist**: Thêm SKAdNetworkItems cho iOS 14+ tracking

### 4. Code Implementation
- **AdMobService**: Service quản lý tất cả ads (Banner, Interstitial, App Open)
- **BannerAdWidget**: Widget hiển thị banner ads
- **Home Page**: Banner ad sau welcome header
- **Categories Screen**: Banner ad ở cuối danh sách episodes
- **Episode Detail Screen**: Interstitial ad khi rời khỏi màn hình
- **Main App**: App Open ad khi khởi động và resume từ background

## Test Ad Unit IDs (Hiện tại đang sử dụng)

### Android
- Banner: `ca-app-pub-2189112136936277/3790180625`
- Interstitial: `ca-app-pub-2189112136936277/9972445596`
- App Open: `ca-app-pub-2189112136936277/1234567890` (cần thay bằng ID thật)

### iOS
- Banner: `ca-app-pub-3940256099942544/2934735716`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`
- App Open: `ca-app-pub-3940256099942544/5575463023`

## Cách test

### 1. Test trên thiết bị thật
```bash
flutter run --release
```

### 2. Kiểm tra logs
- Mở Developer Console để xem logs về ads
- Tìm các message như "Banner ad loaded", "Interstitial ad loaded"

### 3. Test các tình huống
- **Mở ứng dụng lần đầu** → Kiểm tra App Open ad hiển thị
- **Mở Home page** → Kiểm tra banner ad hiển thị
- **Mở Categories** → Kiểm tra banner ad ở cuối danh sách
- **Mở Episode detail** → Rời khỏi màn hình → Kiểm tra interstitial ad
- **Minimize app và mở lại** → Kiểm tra App Open ad (nếu đã qua 4 giờ)

## Lưu ý quan trọng

### 1. Thay thế Test Ad Unit IDs
Khi publish ứng dụng, cần thay thế tất cả test Ad Unit IDs bằng Ad Unit IDs thật từ AdMob Console:
- Tạo app trong AdMob Console
- Tạo Ad Units cho Banner và Interstitial
- Cập nhật trong `AdMobService` class

### 2. App ID
- Android: Cập nhật trong `AndroidManifest.xml`
- iOS: Cập nhật trong `Info.plist`

### 3. Policy Compliance
- Đảm bảo ads không che khuất nội dung quan trọng
- Tuân thủ AdMob policies
- Test kỹ trên nhiều thiết bị và kích thước màn hình

### 4. App Open Ads Best Practices
- **Cooldown**: Đã cài đặt 4 giờ giữa các lần hiển thị để tránh spam
- **Timing**: Hiển thị sau 500ms khi mở app và 1s khi resume
- **User Experience**: Không làm gián đoạn trải nghiệm người dùng
- **Frequency**: Tối đa 1 lần/4 giờ để đảm bảo user retention

## Cấu trúc files đã tạo/sửa đổi

### Files mới:
- `lib/services/admob_service.dart`
- `lib/widgets/banner_ad_widget.dart`

### Files đã sửa đổi:
- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `lib/main.dart`
- `lib/screens/home_page.dart`
- `lib/screens/episode_detail_screen.dart`
- `lib/screens/categories_screen.dart`

## Troubleshooting

### 1. Ads không hiển thị
- Kiểm tra internet connection
- Kiểm tra Ad Unit IDs có đúng không
- Kiểm tra logs trong console
- Đảm bảo test trên thiết bị thật (không phải simulator)

### 2. Lỗi build
- Chạy `flutter clean` và `flutter pub get`
- Kiểm tra Android SDK và iOS deployment target
- Đảm bảo tất cả dependencies được cài đặt đúng

### 3. Performance issues
- Ads có thể ảnh hưởng đến performance
- Monitor memory usage
- Test trên thiết bị cũ để đảm bảo compatibility
