class AppVi {
  static const Map<String, String> texts = {
    // App Info
    'appTitle': 'BBC Học Tiếng Anh',
    'welcomeMessage': 'Chào mừng đến với Learning English với B.B.C!',
    
    // Greetings
    'goodMorning': 'Chào buổi sáng!',
    'goodAfternoon': 'Chào buổi chiều!',
    'goodEvening': 'Chào buổi tối!',
    'learnEnglishThroughListening': 'Học tiếng Anh qua các bài nghe thú vị từ BBC.',
    
    // Navigation
    'home': 'Trang chủ',
    'categories': 'Danh mục',
    'vocabularies': 'Từ vựng',
    'grammar': 'Ngữ pháp',
    'settings': 'Cài đặt',
    
    // Common
    'episodes': 'Episodes',
    'loading': 'Đang tải...',
    'errorOccurred': 'Có lỗi xảy ra',
    'tryAgain': 'Thử lại',
    'noData': 'Không có dữ liệu',
    'refresh': 'Làm mới',
    'ok': 'OK',
    'cancel': 'Hủy',
    'save': 'Lưu',
    'delete': 'Xóa',
    'edit': 'Sửa',
    
    // Audio Controls
    'play': 'Phát',
    'pause': 'Tạm dừng',
    'stop': 'Dừng',
    'next': 'Tiếp theo',
    'previous': 'Trước đó',
    'skipForward': 'Tua +10s',
    'skipBackward': 'Tua -10s',
    
    // Episode Info
    'favorite': 'Yêu thích',
    'download': 'Tải xuống',
    'downloaded': 'Đã tải',
    'episodeInfo': 'Thông tin Episode',
    'transcript': 'Bản ghi',
    'vocabulary': 'Từ vựng',
    'topEpisodes': 'Top 10 Episodes cùng Category',
    'noSummary': 'Không có tóm tắt cho episode này.',
    'actor': 'Diễn viên',
    'year': 'Năm',
    'duration': 'Thời lượng',
    'releaseDate': 'Ngày phát hành',
    'minutesPerLesson': 'Phút/bài',
    
    // Time
    'today': 'Hôm nay',
    'yesterday': 'Hôm qua',
    'daysAgo': '{count} ngày trước',
    
    // Vocabulary
    'saveToVocabulary': 'Lưu vào từ vựng cá nhân',
    'noVocabulary': 'Không có từ vựng cho episode này.',
    'vocabularyList': 'Danh sách từ vựng',
    
    // Settings
    'language': 'Ngôn ngữ',
    'selectLanguage': 'Chọn ngôn ngữ',
    'theme': 'Giao diện',
    'selectTheme': 'Chọn giao diện',
    'fontSize': 'Cỡ chữ',
    'selectFontSize': 'Chọn cỡ chữ',
    'lightTheme': 'Sáng',
    'darkTheme': 'Tối',
    'systemTheme': 'Hệ thống',
    'smallFont': 'Nhỏ',
    'normalFont': 'Bình thường',
    'largeFont': 'Lớn',

    // Saved Screen
    'saved': 'Đã lưu',
    'savedDesc': 'Các episode và từ vựng đã lưu của bạn',
    'favouriteEpisodes': 'Episode yêu thích',
    'noFavouriteEpisodes': 'Chưa có episode yêu thích nào',
    'noFavouriteEpisodesDesc': 'Hãy bấm vào icon trái tim để thêm episode vào danh sách yêu thích',
    'noSavedVocabularies': 'Chưa có vocabulary nào được lưu',
    'noSavedVocabulariesDesc': 'Hãy bấm vào icon bookmark để lưu từ vựng vào danh sách cá nhân',
    'loadingFavourites': 'Đang tải danh sách yêu thích...',
    'loadingVocabularies': 'Đang tải vocabulary...',
    'removeFromFavourites': 'Xóa khỏi yêu thích',
    'addToFavourites': 'Thêm vào yêu thích',
    'removeFromVocabularies': 'Xóa khỏi vocabulary',
    'addToVocabularies': 'Thêm vào vocabulary',

    // Authentication
    'account': 'Tài khoản',
    'login': 'Đăng nhập',
    'register': 'Đăng ký',
    'logout': 'Đăng xuất',
    'email': 'Email',
    'password': 'Mật khẩu',
    'name': 'Tên',
    'loginWithGoogle': 'Đăng nhập với Google',
    'loginToSync': 'Đăng nhập để đồng bộ dữ liệu trên các thiết bị',
    'syncedToCloud': 'Đã đồng bộ lên cloud',
    'logoutConfirm': 'Bạn có chắc chắn muốn đăng xuất?',
    'loginSuccess': 'Đăng nhập thành công!',
    'registerSuccess': 'Đăng ký thành công!',
    'logoutSuccess': 'Đăng xuất thành công!',
    'emailRequired': 'Email là bắt buộc',
    'emailInvalid': 'Vui lòng nhập email hợp lệ',
    'passwordRequired': 'Mật khẩu là bắt buộc',
    'passwordMinLength': 'Mật khẩu phải có ít nhất 6 ký tự',
    'nameRequired': 'Tên là bắt buộc',
    'unknownError': 'Có lỗi không xác định xảy ra',
    
    // Language Names
    'english': 'English',
    'vietnamese': 'Tiếng Việt',
    'arabic': 'العربية',
    'chinese': '中文',
    'korean': '한국어',
    'japanese': '日本語',
    'russian': 'Русский',
    'spanish': 'Español',
    'portuguese': 'Português',

    // Category Group Box
    'newEpisodes': 'Episodes mới nhất',
    'viewAll': 'Xem tất cả',
    'selectCategoryToExploreEpisodes': 'Chọn danh mục để khám phá episodes',

    // Settings
    'imageCache': 'Cache ảnh',
    'manageImageCache': 'Quản lý cache ảnh',
    'cacheSize': 'Kích thước cache',
    'clearCache': 'Xóa cache',
    
    // Grammar
    'grammarLessons': 'Bài học ngữ pháp',
    'theory': 'Lý thuyết',
    'description': 'Mô tả',
    'parts': 'phần',
    'noGrammarContent': 'Không có nội dung ngữ pháp',
  };
}
