# Hệ thống Cache Image cho BBC Learning English App

## Tổng quan

Hệ thống cache image được thiết kế để tối ưu hóa hiệu suất hiển thị hình ảnh trong ứng dụng BBC Learning English. Thay vì tải lại hình ảnh từ internet mỗi lần hiển thị, hệ thống sẽ lưu trữ hình ảnh trong bộ nhớ cache để truy cập nhanh hơn.

## Các tính năng chính

### 1. **Cached Network Image**
- Sử dụng package `cached_network_image` để cache hình ảnh
- Tự động tải và lưu trữ hình ảnh từ URL
- Hiển thị placeholder và error widget tùy chỉnh

### 2. **Image Cache Service**
- Service quản lý tập trung cho việc cache hình ảnh
- Cung cấp API đơn giản để hiển thị hình ảnh với cache
- Quản lý kích thước cache và thời gian lưu trữ

### 3. **Preloading**
- Tự động preload hình ảnh quan trọng
- Cải thiện trải nghiệm người dùng bằng cách tải trước hình ảnh

### 4. **Cache Management**
- Xem kích thước cache hiện tại
- Xóa cache khi cần thiết
- Tự động dọn dẹp cache cũ

## Cách sử dụng

### Hiển thị hình ảnh với cache

```dart
ImageCacheService().buildCachedImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 100,
  height: 100,
  fit: BoxFit.cover,
  borderRadius: BorderRadius.circular(8),
)
```

### Preload hình ảnh

```dart
// Preload một hình ảnh
await ImageCacheService().preloadImage('https://example.com/image.jpg');

// Preload nhiều hình ảnh
await ImageCacheService().preloadImages([
  'https://example.com/image1.jpg',
  'https://example.com/image2.jpg',
]);
```

### Quản lý cache

```dart
// Lấy kích thước cache
int cacheSize = await ImageCacheService().getCacheSize();

// Xóa cache
await ImageCacheService().clearCache();

// Format kích thước cache
String formattedSize = ImageCacheService().formatCacheSize(cacheSize);
```

## Cấu hình

### Kích thước cache tối đa
```dart
static const int _maxCacheSize = 100; // Số lượng ảnh tối đa
```

### Thời gian cache
```dart
static const Duration _cacheDuration = Duration(days: 7); // 7 ngày
```

### Độ phân giải cache
```dart
memCacheWidth: width.toInt(),
memCacheHeight: height.toInt(),
maxWidthDiskCache: (width * 2).toInt(), // Cache với độ phân giải cao hơn
maxHeightDiskCache: (height * 2).toInt(),
```

## Lợi ích

### 1. **Hiệu suất**
- Giảm thời gian tải hình ảnh
- Giảm sử dụng băng thông
- Cải thiện trải nghiệm người dùng

### 2. **Tiết kiệm tài nguyên**
- Giảm số lượng request HTTP
- Tiết kiệm dữ liệu di động
- Giảm tải cho server

### 3. **Offline Support**
- Hình ảnh đã cache có thể hiển thị offline
- Cải thiện trải nghiệm khi mạng chậm

## Tối ưu hóa

### 1. **Preloading Strategy**
- Preload hình ảnh của 3 episode đầu tiên trong mỗi category
- Chỉ preload khi cần thiết để tiết kiệm băng thông

### 2. **Memory Management**
- Tự động dọn dẹp cache cũ
- Giới hạn kích thước cache
- Sử dụng LRU (Least Recently Used) algorithm

### 3. **Error Handling**
- Hiển thị placeholder khi đang tải
- Hiển thị error widget khi tải thất bại
- Fallback graceful khi có lỗi

## Monitoring

### Cache Size Tracking
- Hiển thị kích thước cache trong Settings
- Cho phép người dùng xóa cache
- Refresh thông tin cache

### Performance Metrics
- Thời gian tải hình ảnh
- Tỷ lệ cache hit/miss
- Sử dụng băng thông

## Troubleshooting

### Cache không hoạt động
1. Kiểm tra quyền truy cập storage
2. Kiểm tra kết nối internet
3. Xóa cache và thử lại

### Cache quá lớn
1. Giảm `_maxCacheSize`
2. Giảm `_cacheDuration`
3. Thường xuyên dọn dẹp cache

### Hình ảnh không hiển thị
1. Kiểm tra URL hình ảnh
2. Kiểm tra error widget
3. Kiểm tra placeholder widget

## Tương lai

### Planned Features
- [ ] Cache compression
- [ ] Smart preloading based on user behavior
- [ ] Cache analytics
- [ ] Background cache cleanup
- [ ] Cache sharing between app sessions
