# Hướng dẫn Setup Firebase Realtime Database cho AI Cache

## Tổng quan

Firebase Realtime Database được sử dụng để chia sẻ AI responses giữa users, giúp tiết kiệm chi phí API. Cấu trúc database sẽ tự động được tạo khi app sử dụng lần đầu.

## Cấu trúc Database

```
/ai_cache/
  /translations/
    /{episodeId}/
      /{languageCode}/          // e.g., "vi", "zh", "ja"
        {
          "data": {
            "translations": { ... }
          },
          "createdAt": "2024-01-01T00:00:00.000Z",
          "version": 1,
          "ttlDays": 90
        }
  
  /grammar/
    /{sentenceHash}/            // Hash của sentence
      {
        "data": {
          "grammarPoint": "...",
          "explanation": "...",
          "highlightedWords": [...]
        },
        "createdAt": "...",
        "version": 1,
        "ttlDays": 90
      }
  
  /questions/
    /{episodeId}/
      /{count}/                 // e.g., 5, 10
        {
          "data": {
            "questions": [...],
            "count": 5
          },
          "createdAt": "...",
          "version": 1,
          "ttlDays": 90
        }
  
  /vocabulary/
    /{wordHash}/                // Hash của word
      {
        "data": {
          "synonyms": [...],
          "antonyms": [...],
          "exampleSentences": [...],
          ...
        },
        "createdAt": "...",
        "version": 1,
        "ttlDays": 180
      }
  
  /access_stats/
    /{episodeId}/
      {
        "episodeId": "...",
        "count": 123,
        "lastAccessed": "..."
      }
```

## Bước 1: Setup Database Rules

### Cách 1: Sử dụng Firebase Console (Khuyến nghị)

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Chọn project: **bbc-listening-english**
3. Vào **Realtime Database** → **Rules**
4. Copy và paste rules từ file `database.rules.json`:

```json
{
  "rules": {
    "ai_cache": {
      ".read": true,
      ".write": true,
      ...
    }
  }
}
```

5. Click **Publish** để lưu rules

### Cách 2: Sử dụng Firebase CLI

```bash
# Install Firebase CLI (nếu chưa có)
npm install -g firebase-tools

# Login
firebase login

# Init Firebase (nếu chưa có)
firebase init database

# Deploy rules
firebase deploy --only database
```

## Bước 2: Kiểm tra Database

### Kiểm tra trong Firebase Console

1. Vào **Realtime Database** → **Data**
2. Kiểm tra xem có path `/ai_cache` chưa
3. Khi app chạy lần đầu và sử dụng AI features, data sẽ tự động được tạo

### Test thủ công

Bạn có thể test bằng cách thêm data thủ công trong Firebase Console:

```json
{
  "ai_cache": {
    "translations": {
      "test-episode-1": {
        "vi": {
          "data": {
            "translations": {
              "Hello": "Xin chào",
              "World": "Thế giới"
            }
          },
          "createdAt": "2024-01-01T00:00:00.000Z",
          "version": 1,
          "ttlDays": 90
        }
      }
    }
  }
}
```

## Bước 3: Security Rules

### Rules hiện tại (Public Read/Write)

```json
{
  "rules": {
    "ai_cache": {
      ".read": true,   // Ai cũng có thể đọc
      ".write": true   // Ai cũng có thể ghi
    }
  }
}
```

**Lý do**: AI cache là public data, không chứa thông tin cá nhân, nên có thể public để chia sẻ giữa users.

### Nếu muốn bảo mật hơn (Optional)

Nếu bạn muốn chỉ authenticated users mới có thể write:

```json
{
  "rules": {
    "ai_cache": {
      ".read": true,
      ".write": "auth != null"  // Chỉ authenticated users mới write được
    }
  }
}
```

**Lưu ý**: Nếu dùng rule này, bạn cần đảm bảo app có authentication flow.

## Bước 4: Monitoring & Analytics

### Xem usage trong Firebase Console

1. Vào **Realtime Database** → **Usage**
2. Xem số lượng reads/writes
3. Monitor storage usage

### Popular Episodes

App tự động track popular episodes trong `/ai_cache/access_stats/`. Bạn có thể:

1. Xem trong Firebase Console
2. Sử dụng để optimize cache strategy
3. Pre-cache popular episodes nếu cần

## Bước 5: Cost Optimization

### Free Tier Limits

- **Storage**: 1 GB
- **Bandwidth**: 10 GB/month
- **Simultaneous connections**: 100

### Tips để tiết kiệm

1. **TTL (Time To Live)**: Cache tự động expire sau 90-180 days
2. **Compression**: Data đã được optimize (chỉ lưu cần thiết)
3. **Popular Episodes**: Chỉ cache popular content

### Nếu vượt free tier

- **Blaze Plan**: Pay as you go
- **Cost**: ~$5/TB storage, $1/GB bandwidth
- Với 1000 users, ước tính ~$1-5/month

## Troubleshooting

### Lỗi: Permission denied

**Nguyên nhân**: Database rules chưa được setup đúng

**Giải pháp**:
1. Kiểm tra rules trong Firebase Console
2. Đảm bảo `.read: true` và `.write: true` cho `/ai_cache`
3. Click **Publish** để apply rules

### Lỗi: Database not found

**Nguyên nhân**: Realtime Database chưa được enable

**Giải pháp**:
1. Vào Firebase Console
2. **Realtime Database** → **Create Database**
3. Chọn location (gần nhất với users)
4. Start in **test mode** hoặc **locked mode** (sẽ update rules sau)

### Lỗi: Network timeout

**Nguyên nhân**: Firebase connection issues

**Giải pháp**:
1. Kiểm tra internet connection
2. Check Firebase status: https://status.firebase.google.com/
3. Code đã có timeout 5 seconds và fallback về local cache

## Best Practices

### 1. Monitor Storage Usage

- Check `/ai_cache` size định kỳ
- Remove old cache entries nếu cần
- Set up alerts trong Firebase Console

### 2. Version Control

- Cache entries có `version` field
- Khi update AI model, có thể invalidate old cache
- Code tự động check version

### 3. TTL Management

- Translations/Grammar/Questions: 90 days
- Vocabulary: 180 days
- Tự động expire và cleanup

### 4. Error Handling

- Code đã có error handling
- Fail silently, fallback về local cache
- Không block user experience

## Kết luận

**Bạn KHÔNG cần setup gì thêm trong database!**

- Database structure sẽ tự động được tạo khi app sử dụng
- Chỉ cần setup **Database Rules** trong Firebase Console
- Copy rules từ `database.rules.json` và publish

**Next Steps**:
1. ✅ Setup database rules (5 phút)
2. ✅ Test app với AI features
3. ✅ Monitor usage trong Firebase Console

