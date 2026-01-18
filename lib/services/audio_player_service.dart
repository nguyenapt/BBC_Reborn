import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/local_database_service.dart';
import '../services/episode_download_service.dart';
import 'notification_service.dart';

enum AudioPlayerState { stopped, playing, paused, loading }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final NotificationService _notificationService = NotificationService();
  final StorageService _storageService = StorageService();
  final FirebaseStorageService _firebaseStorageService = FirebaseStorageService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final LocalDatabaseService _localDatabaseService = LocalDatabaseService();
  final EpisodeDownloadService _downloadService = EpisodeDownloadService();
  
  AudioPlayerState _playerState = AudioPlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Episode? _currentEpisode;
  List<Episode> _currentCategoryEpisodes = [];
  int _currentEpisodeIndex = 0;
  bool _isFavourite = false;
  bool _isDownloaded = false;
  String? _currentAudioUrl;
  
  // Biến để track trạng thái trước khi bị gián đoạn (cuộc gọi điện thoại)
  bool _wasPlayingBeforeInterruption = false;
  Duration _positionBeforeInterruption = Duration.zero;

  // Getters
  AudioPlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  int get currentPositionMs => _currentPosition.inMilliseconds;
  Duration get totalDuration => _totalDuration;
  Episode? get currentEpisode => _currentEpisode;
  List<Episode> get currentCategoryEpisodes => _currentCategoryEpisodes;
  int get currentEpisodeIndex => _currentEpisodeIndex;
  bool get isFavourite => _isFavourite;
  bool get isDownloaded => _isDownloaded;
  bool get isPlaying => _playerState == AudioPlayerState.playing;
  bool get isPaused => _playerState == AudioPlayerState.paused;
  bool get isLoading => _playerState == AudioPlayerState.loading;

  // Timer để cập nhật position
  Timer? _positionTimer;

  /// Initialize service
  Future<void> initialize() async {
    await _userService.initialize();
    
    // Cấu hình AudioContext cho background playback
    await _audioPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.allowBluetooth,
          AVAudioSessionOptions.allowBluetoothA2DP,
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    ));
  }

  /// Load episode và category episodes
  Future<void> loadEpisode(Episode episode) async {
    _currentEpisode = episode;
    _playerState = AudioPlayerState.stopped;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    
    // Determine audio URL với fallback
    _currentAudioUrl = _getAudioUrl(episode);
    
    // Load episodes cùng category
    try {
      final categories = await _firebaseService.getHomePageData();
      for (final category in categories) {
        if (category.name == episode.category) {
          _currentCategoryEpisodes = category.episodes;
          _currentEpisodeIndex = _currentCategoryEpisodes.indexWhere((e) => e.id == episode.id);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error loading category episodes: $e');
    }
    
    // Check favourite status
    _isFavourite = await _checkFavouriteStatus(episode.id ?? '');
    
    // Check download status
    _isDownloaded = await _checkDownloadStatus(episode.id ?? '');
    
    notifyListeners();
  }

  /// Load episode với category episodes được truyền vào
  Future<void> loadEpisodeWithCategory(Episode episode, List<Episode> categoryEpisodes) async {
    _currentEpisode = episode;
    _playerState = AudioPlayerState.stopped;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    
    // Stop current audio nếu đang play
    await _audioPlayer.stop();
    
    // Set category episodes và index
    _currentCategoryEpisodes = categoryEpisodes;
    _currentEpisodeIndex = categoryEpisodes.indexWhere((e) => e.id == episode.id);
    
    if (_currentEpisodeIndex == -1) {
      _currentEpisodeIndex = 0;
    }
    
    // Determine audio URL với fallback
    _currentAudioUrl = _getAudioUrl(episode);
    
    // Check favourite status
    _isFavourite = await _checkFavouriteStatus(episode.id ?? '');
    
    // Check download status
    _isDownloaded = await _checkDownloadStatus(episode.id ?? '');
    
    // Show notification
    await _notificationService.showAudioNotification(
      episode, 
      false, // Show notification as paused
      duration: _totalDuration.inMilliseconds,
      currentPosition: _currentPosition.inMilliseconds,
    );
    
    notifyListeners();
  }

  /// Lấy audio URL với fallback logic
  String? _getAudioUrl(Episode episode) {
    // Ưu tiên fileUrl trước
    if (episode.fileUrl != null && episode.fileUrl!.isNotEmpty) {
      return episode.fileUrl;
    }
    // Fallback sang secondFileUrl
    if (episode.secondFileUrl != null && episode.secondFileUrl!.isNotEmpty) {
      return episode.secondFileUrl;
    }
    return null;
  }

  /// Play audio
  Future<void> play() async {
    if (_currentEpisode == null || _currentAudioUrl == null) {
      debugPrint('No episode or audio URL available');
      return;
    }
    
    _playerState = AudioPlayerState.loading;
    notifyListeners();
    
    try {
      // Set up audio player listeners
      _setupAudioPlayerListeners();
      
      // Play audio from URL or local file
      final source = _buildAudioSource(_currentAudioUrl!);
      await _audioPlayer.play(source);
      
      _playerState = AudioPlayerState.playing;
      notifyListeners();
      
      // Update notification
      if (_currentEpisode != null) {
        await _notificationService.updateNotification(
          _currentEpisode!, 
          true,
          duration: _totalDuration.inMilliseconds,
          currentPosition: _currentPosition.inMilliseconds,
        );
      }
    } catch (e) {
      _playerState = AudioPlayerState.stopped;
      notifyListeners();
      debugPrint('Error playing audio: $e');
    }
  }

  /// Setup audio player listeners
  void _setupAudioPlayerListeners() {
    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((Duration position) {
      _currentPosition = position;
      notifyListeners();
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) async {
      switch (state) {
        case PlayerState.playing:
          _playerState = AudioPlayerState.playing;
          break;
        case PlayerState.paused:
          _playerState = AudioPlayerState.paused;
          break;
        case PlayerState.stopped:
          _playerState = AudioPlayerState.stopped;
          _currentPosition = Duration.zero;
          break;
        case PlayerState.completed:
          _playerState = AudioPlayerState.stopped;
          _currentPosition = Duration.zero;
          break;
        default:
          break;
      }
      notifyListeners();
      
      // Update notification when state changes
      if (_currentEpisode != null) {
        await _notificationService.updateNotification(
          _currentEpisode!, 
          _playerState == AudioPlayerState.playing,
          duration: _totalDuration.inMilliseconds,
          currentPosition: _currentPosition.inMilliseconds,
        );
      }
    });
  }

  /// Pause audio
  Future<void> pause() async {
    if (_playerState == AudioPlayerState.playing) {
      await _audioPlayer.pause();
      _playerState = AudioPlayerState.paused;
      notifyListeners();
      
      // Update notification
      if (_currentEpisode != null) {
        await _notificationService.updateNotification(
          _currentEpisode!, 
          false,
          duration: _totalDuration.inMilliseconds,
          currentPosition: _currentPosition.inMilliseconds,
        );
      }
    }
  }

  /// Resume audio
  Future<void> resume() async {
    if (_playerState == AudioPlayerState.paused) {
      await _audioPlayer.resume();
      _playerState = AudioPlayerState.playing;
      notifyListeners();
      
      // Update notification
      if (_currentEpisode != null) {
        await _notificationService.updateNotification(
          _currentEpisode!, 
          true,
          duration: _totalDuration.inMilliseconds,
          currentPosition: _currentPosition.inMilliseconds,
        );
      }
    }
  }

  /// Stop audio
  Future<void> stop() async {
    await _audioPlayer.stop();
    _playerState = AudioPlayerState.stopped;
    _currentPosition = Duration.zero;
    notifyListeners();
    
    // Hide notification
    await _notificationService.hideNotification();
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _currentPosition = position;
    notifyListeners();
  }

  /// Skip forward 10 seconds
  Future<void> skipForward() async {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    if (newPosition <= _totalDuration) {
      await seekTo(newPosition);
    }
  }

  /// Skip backward 10 seconds
  Future<void> skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    if (newPosition >= Duration.zero) {
      await seekTo(newPosition);
    } else {
      await seekTo(Duration.zero);
    }
  }

  /// Next episode
  Future<void> nextEpisode() async {
    if (_currentEpisodeIndex < _currentCategoryEpisodes.length - 1) {
      final nextEpisode = _currentCategoryEpisodes[_currentEpisodeIndex + 1];
      await loadEpisodeWithCategory(nextEpisode, _currentCategoryEpisodes);
    } else {
      debugPrint('No next episode available');
    }
  }

  /// Previous episode
  Future<void> previousEpisode() async {
    if (_currentEpisodeIndex > 0) {
      final prevEpisode = _currentCategoryEpisodes[_currentEpisodeIndex - 1];
      await loadEpisodeWithCategory(prevEpisode, _currentCategoryEpisodes);
    } else {
      debugPrint('No previous episode available');
    }
  }

  /// Toggle favourite
  Future<void> toggleFavourite() async {
    if (_currentEpisode == null) return;
    
    _isFavourite = !_isFavourite;
    await _saveFavouriteStatus(_currentEpisode!.id ?? '', _isFavourite);
    notifyListeners();
  }

  /// Download episode
  Future<void> downloadEpisode() async {
    if (_currentEpisode == null) return;
    
    try {
      final episode = _currentEpisode!;
      final episodeId = episode.id;
      if (episodeId == null || episodeId.isEmpty) return;

      final remoteUrl = _getRemoteAudioUrl(episode);
      if (remoteUrl == null) return;

      final fileName = '$episodeId.mp3';
      final localPath = await _downloadService.downloadAudio(
        url: remoteUrl,
        fileName: fileName,
      );
      if (localPath == null) return;

      final updatedEpisode = _copyEpisodeWithFileUrl(episode, localPath);
      await _localDatabaseService.upsertEpisode(updatedEpisode);
      _updateCurrentEpisode(updatedEpisode);
      _currentAudioUrl = localPath;
      _isDownloaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error downloading episode: $e');
    }
  }

  /// Check favourite status
  Future<bool> _checkFavouriteStatus(String episodeId) async {
    try {
      // Check local storage first
      final localFavourite = await _storageService.isEpisodeFavourite(episodeId);
      if (localFavourite) return true;
      
      // Check Firebase storage
      final firebaseFavourite = await _firebaseStorageService.isEpisodeFavourite(_userService.userId, episodeId);
      return firebaseFavourite;
    } catch (e) {
      debugPrint('Error checking favourite status: $e');
      return false;
    }
  }

  /// Save favourite status
  Future<void> _saveFavouriteStatus(String episodeId, bool isFavourite) async {
    try {
      if (isFavourite) {
        // Save complete episode data to local storage
        if (_currentEpisode != null) {
          await _storageService.addFavouriteEpisode(_currentEpisode!);
        }
        // Only save to Firebase if user is logged in
        if (_authService.isLoggedIn) {
          await _firebaseStorageService.addFavouriteEpisode(_userService.userId, episodeId);
        }
      } else {
        await _storageService.removeFavouriteEpisode(episodeId);
        // Only remove from Firebase if user is logged in
        if (_authService.isLoggedIn) {
          await _firebaseStorageService.removeFavouriteEpisode(_userService.userId, episodeId);
        }
      }
    } catch (e) {
      debugPrint('Error saving favourite status: $e');
    }
  }

  /// Check download status
  Future<bool> _checkDownloadStatus(String episodeId) async {
    final fileUrl = await _localDatabaseService.getEpisodeFileUrl(episodeId);
    if (fileUrl == null || fileUrl.isEmpty) return false;
    final exists = await _downloadService.fileExists(fileUrl);
    if (!exists) return false;
    if (_currentEpisode != null && _currentEpisode!.id == episodeId) {
      final updatedEpisode = _copyEpisodeWithFileUrl(_currentEpisode!, fileUrl);
      _updateCurrentEpisode(updatedEpisode);
      _currentAudioUrl = fileUrl;
    }
    return true;
  }

  /// Save download status
  Future<void> _saveDownloadStatus(String episodeId, bool isDownloaded) async {
    // Download status is derived from local file presence
  }

  Source _buildAudioSource(String url) {
    if (_isRemoteUrl(url)) {
      return UrlSource(url);
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'file') {
      return DeviceFileSource(uri.toFilePath());
    }
    return DeviceFileSource(url);
  }

  bool _isRemoteUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String? _getRemoteAudioUrl(Episode episode) {
    final primary = episode.fileUrl ?? '';
    if (primary.isNotEmpty && _isRemoteUrl(primary)) {
      return primary;
    }
    final fallback = episode.secondFileUrl ?? '';
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  Episode _copyEpisodeWithFileUrl(Episode episode, String fileUrl) {
    return Episode(
      id: episode.id,
      actor: episode.actor,
      category: episode.category,
      duration: episode.duration,
      publishedDate: episode.publishedDate,
      episodeName: episode.episodeName,
      transcript: episode.transcript,
      thumbImage: episode.thumbImage,
      fileUrl: fileUrl,
      secondFileUrl: episode.secondFileUrl,
      summary: episode.summary,
      year: episode.year,
      transcriptHtml: episode.transcriptHtml,
      vocabulary: episode.vocabulary,
      vocabularies: episode.vocabularies,
    );
  }

  void _updateCurrentEpisode(Episode updatedEpisode) {
    _currentEpisode = updatedEpisode;
    final index = _currentCategoryEpisodes.indexWhere((e) => e.id == updatedEpisode.id);
    if (index != -1) {
      _currentCategoryEpisodes[index] = updatedEpisode;
    }
  }

  /// Xử lý khi có cuộc gọi điện thoại đến (app bị gián đoạn)
  Future<void> handleInterruption() async {
    if (_playerState == AudioPlayerState.playing) {
      debugPrint('📞 Phone call incoming - pausing audio');
      
      // Lưu trạng thái hiện tại
      _wasPlayingBeforeInterruption = true;
      _positionBeforeInterruption = _currentPosition;
      
      // Tạm dừng audio
      await pause();
      
      debugPrint('📞 Audio paused due to phone call');
    }
  }

  /// Xử lý khi cuộc gọi điện thoại kết thúc (app được resume)
  Future<void> handleResumeAfterInterruption() async {
    if (_wasPlayingBeforeInterruption) {
      debugPrint('📞 Phone call ended - resuming audio');
      
      // Seek về vị trí trước khi bị gián đoạn
      await seekTo(_positionBeforeInterruption);
      
      // Tiếp tục play
      await play();
      
      // Reset trạng thái
      _wasPlayingBeforeInterruption = false;
      _positionBeforeInterruption = Duration.zero;
      
      debugPrint('📞 Audio resumed after phone call');
    }
  }

  /// Xử lý app lifecycle changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App bị pause hoặc inactive - KHÔNG tự động pause audio
        // Chỉ pause khi có cuộc gọi điện thoại (được xử lý riêng)
        debugPrint('App paused/inactive - audio continues playing in background');
        break;
      case AppLifecycleState.resumed:
        // App được resume - không cần làm gì đặc biệt
        debugPrint('App resumed - audio continues playing');
        break;
      case AppLifecycleState.detached:
        // App bị terminate - dừng audio
        stop();
        break;
      case AppLifecycleState.hidden:
        // App bị ẩn - audio vẫn tiếp tục phát
        debugPrint('App hidden - audio continues playing in background');
        break;
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
