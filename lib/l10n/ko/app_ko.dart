class AppKo {
  static const Map<String, String> texts = {
    // App Info
    'appTitle': 'BBC 영어 학습',
    'welcomeMessage': '「6분으로 영어를 배우자」에 오신 것을 환영합니다!',
    
    // Greetings
    'goodMorning': '좋은 아침입니다!',
    'goodAfternoon': '좋은 오후입니다!',
    'goodEvening': '좋은 저녁입니다!',
    'learnEnglishThroughListening': '흥미로운 듣기 자료로 영어를 배우세요.',
    
    // Navigation
    'home': '홈',
    'categories': '카테고리',
    'vocabularies': '어휘',
    'grammar': '문법',
    'settings': '설정',
    
    // Common
    'episodes': '에피소드',
    'loading': '로딩 중...',
    'errorOccurred': '오류가 발생했습니다',
    'tryAgain': '다시 시도',
    'noData': '데이터 없음',
    'refresh': '새로고침',
    'ok': '확인',
    'cancel': '취소',
    'save': '저장',
    'delete': '삭제',
    'edit': '편집',
    
    // Audio Controls
    'play': '재생',
    'pause': '일시정지',
    'stop': '중지',
    'next': '다음',
    'previous': '이전',
    'skipForward': '앞으로 +10초',
    'skipBackward': '뒤로 -10초',
    
    // Episode Info
    'favorite': '즐겨찾기',
    'download': '다운로드',
    'downloaded': '다운로드됨',
    'episodeInfo': '에피소드 정보',
    'transcript': '대본',
    'vocabulary': '어휘',
    'topEpisodes': '같은 카테고리 상위 10개 에피소드',
    'noSummary': '이 에피소드에 대한 요약이 없습니다.',
    'actor': '배우',
    'year': '연도',
    'duration': '재생시간',
    'releaseDate': '출시일',
    'minutesPerLesson': '분/수업',
    
    // Time
    'today': '오늘',
    'yesterday': '어제',
    'daysAgo': '{count}일 전',
    
    // Vocabulary
    'saveToVocabulary': '개인 어휘에 저장',
    'noVocabulary': '이 에피소드에 대한 어휘가 없습니다.',
    'vocabularyList': '어휘 목록',
    
    // Settings
    'language': '언어',
    'selectLanguage': '언어 선택',
    'theme': '테마',
    'selectTheme': '테마 선택',
    'fontSize': '글꼴 크기',
    'selectFontSize': '글꼴 크기 선택',
    'lightTheme': '라이트',
    'darkTheme': '다크',
    'systemTheme': '시스템',
    'smallFont': '작게',
    'normalFont': '보통',
    'largeFont': '크게',

    // Saved Screen
    'saved': '저장됨',
    'savedDesc': '저장된 에피소드와 어휘',
    'favouriteEpisodes': '즐겨찾기 에피소드',
    'noFavouriteEpisodes': '즐겨찾기 에피소드가 없습니다',
    'noFavouriteEpisodesDesc': '하트 아이콘을 눌러 에피소드를 즐겨찾기에 추가하세요',
    'noSavedVocabularies': '저장된 어휘가 없습니다',
    'noSavedVocabulariesDesc': '북마크 아이콘을 눌러 어휘를 개인 목록에 저장하세요',
    'loadingFavourites': '즐겨찾기 로딩 중...',
    'loadingVocabularies': '어휘 로딩 중...',
    'removeFromFavourites': '즐겨찾기에서 제거',
    'addToFavourites': '즐겨찾기에 추가',
    'removeFromVocabularies': '어휘에서 제거',
    'addToVocabularies': '어휘에 추가',

    // Authentication
    'account': '계정',
    'login': '로그인',
    'register': '회원가입',
    'logout': '로그아웃',
    'email': '이메일',
    'password': '비밀번호',
    'name': '이름',
    'loginWithGoogle': 'Google로 로그인',
    'loginToSync': '기기 간 데이터 동기화를 위해 로그인하세요',
    'syncedToCloud': '클라우드에 동기화됨',
    'logoutConfirm': '로그아웃하시겠습니까?',
    'loginSuccess': '로그인 성공!',
    'registerSuccess': '회원가입 성공!',
    'logoutSuccess': '로그아웃 성공!',
    'emailRequired': '이메일은 필수입니다',
    'emailInvalid': '유효한 이메일을 입력하세요',
    'passwordRequired': '비밀번호는 필수입니다',
    'passwordMinLength': '비밀번호는 최소 6자 이상이어야 합니다',
    'nameRequired': '이름은 필수입니다',
    'unknownError': '알 수 없는 오류가 발생했습니다',
    
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
    'newEpisodes': '새로운 에피소드',
    'viewAll': '모두 보기',
    'selectCategoryToExploreEpisodes': '카테고리를 선태하여 에피소드를 탐색',

    // Settings
    'imageCache': '이미지 캐시',
    'manageImageCache': '이미지 캐시 관리',
    'cacheSize': '캐시 크기',
    'clearCache': '캐시 지우기',
    'grammarDesc': '문법 수업과 이론',
    'settingsDesc': '앱 설정',
    'addToFavouritesDesc': '하트 아이콘을 눌러 에피소드를 즐겨찾기에 추가하세요',
    'addToVocabulariesDesc': '북마크 아이콘을 눌러 어휘를 개인 목록에 저장하세요',
    'removedFromVocabularies': '어휘에서 제거',
    'loadingFavouritesError': '즐겨찾기 로딩 중...',
    'loadingVocabulariesError': '어휘 로딩 중...',
    'loadingFavouritesErrorDesc': '오류가 발생했습니다: {error}',
    'loadingVocabulariesErrorDesc': '오류가 발생했습니다: {error}',
    'doubleBackExit': '뒤로 버튼을 다시 눌러 종료',
  };
}
