# Hướng dẫn lấy Gemini API Key

**Tài liệu chính thức:** https://ai.google.dev/gemini-api/docs/api-key

## Bước 1: Truy cập Google AI Studio

1. Mở trình duyệt và truy cập: **https://aistudio.google.com/**
2. Đăng nhập bằng tài khoản Google của bạn

## Bước 2: Tạo API Key

1. Sau khi đăng nhập, bạn sẽ thấy trang **Google AI Studio**
2. Click vào menu **"Get API key"** hoặc **"API Keys"** ở góc trên bên phải
3. Nếu chưa có project, Google sẽ yêu cầu bạn:
   - Chọn hoặc tạo một Google Cloud Project
   - Bạn có thể chọn project mặc định hoặc tạo mới
4. Click **"Create API key"** hoặc **"Create API key in new project"**

## Bước 3: Copy API Key

1. Sau khi tạo, bạn sẽ thấy API key dạng: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
2. **Copy API key này** (bạn chỉ thấy được một lần, hãy lưu lại cẩn thận)
3. Click **"Close"** để đóng dialog

## Bước 4: Cấu hình vào ứng dụng

### Cách 1: Thêm trực tiếp vào code (Không khuyến nghị cho production)

Mở file `lib/config/ai_config.dart` và thay thế:

```dart
static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
```

Thành:

```dart
static const String geminiApiKey = 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'; // API key của bạn
```

### Cách 2: Sử dụng Environment Variables (Khuyến nghị - Theo Google Official Guide)

Theo [tài liệu chính thức của Google](https://ai.google.dev/gemini-api/docs/api-key), bạn có thể set environment variable `GEMINI_API_KEY` hoặc `GOOGLE_API_KEY` (GOOGLE_API_KEY có priority cao hơn).

#### Windows:
1. Search "Environment Variables" trong search bar
2. Chọn "Environment Variables" trong System Settings
3. Click "New..." trong User variables hoặc System variables
4. Variable name: `GEMINI_API_KEY` hoặc `GOOGLE_API_KEY`
5. Variable value: API key của bạn
6. Click OK và mở terminal mới

#### Linux/macOS (Bash):
```bash
# Thêm vào ~/.bashrc
export GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Hoặc
export GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Apply changes
source ~/.bashrc
```

#### Linux/macOS (Zsh):
```bash
# Thêm vào ~/.zshrc
export GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Hoặc
export GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Apply changes
source ~/.zshrc
```

Code đã tự động detect environment variables này!

### Cách 3: Sử dụng Build Arguments (Tốt nhất cho production)

Khi build app, truyền API key qua build arguments:

```bash
# Sử dụng GEMINI_API_KEY
flutter build apk --dart-define=GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Hoặc sử dụng GOOGLE_API_KEY (có priority cao hơn)
flutter build apk --dart-define=GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Code đã tự động hỗ trợ cả hai environment variables này!

## Bước 5: Kiểm tra API Key

1. Chạy ứng dụng
2. Thử sử dụng tính năng AI (translation, grammar, etc.)
3. Nếu có lỗi, kiểm tra console log để xem thông báo lỗi

## Lưu ý quan trọng

### Giới hạn Free Tier
- **15 requests/minute** (60 requests/4 phút)
- **1,500 requests/day**
- **Hoàn toàn miễn phí** trong giới hạn này

### Bảo mật (Theo Google Official Guide)

Theo [tài liệu chính thức](https://ai.google.dev/gemini-api/docs/api-key#keep-your-api-key-secure):

- ⚠️ **KHÔNG commit API key vào Git** - Never commit API keys to source control
- ⚠️ **KHÔNG expose API key trên client-side** - Do not use API key directly in web/mobile apps in production
- ✅ **Sử dụng server-side calls** - The most secure way is to call Gemini API from server-side
- ✅ **Sử dụng environment variables** - Set `GEMINI_API_KEY` hoặc `GOOGLE_API_KEY`
- ✅ **Restrict API key** - Add restrictions to your key (IP addresses, HTTP referrers, etc.)
- ✅ **Regular audits** - Regularly audit and rotate API keys

**Best Practice:** Sử dụng environment variables hoặc build arguments, không hardcode API key trong code!

### Nếu vượt quá giới hạn
- Ứng dụng sẽ tự động fallback sang OpenAI (nếu đã cấu hình)
- Hoặc hiển thị thông báo lỗi rate limit
- Đợi 1 phút để reset rate limit

## Troubleshooting

### Lỗi "API key not configured"
- Kiểm tra xem đã thay `YOUR_GEMINI_API_KEY` bằng API key thực tế chưa
- Kiểm tra xem API key có đúng format không (bắt đầu bằng `AIzaSy`)

### Lỗi "Rate limit exceeded"
- Đã vượt quá 15 requests/minute
- Đợi 1 phút hoặc sử dụng OpenAI backup

### Lỗi "Invalid API key"
- API key không đúng hoặc đã bị thu hồi
- Tạo API key mới và cập nhật lại

## Liên kết hữu ích

- **Official API Key Guide:** https://ai.google.dev/gemini-api/docs/api-key
- **Google AI Studio:** https://aistudio.google.com/
- **Gemini API Documentation:** https://ai.google.dev/docs
- **Pricing:** https://ai.google.dev/pricing (Free tier available)
- **Model Names:** `gemini-2.5-flash` (latest), `gemini-1.5-flash`, `gemini-pro`

