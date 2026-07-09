import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../services/local_database_service.dart';
import '../services/episode_download_service.dart';
import '../utils/debug_source_log.dart';
import 'learning_progress_service.dart';
import 'notification_service.dart';
import 'media_notification_launch_handler.dart';

enum AudioPlayerState { stopped, playing, paused, loading }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final NotificationService _notificationService = NotificationService();
  final StorageService _storageService = StorageService();
  final UserService _userService = UserService();
  final LocalDatabaseService _localDatabaseService = LocalDatabaseService();
  final EpisodeDownloadService _downloadService = EpisodeDownloadService();
  final LearningProgressService _learningProgress = LearningProgressService();
  
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
  bool get isEffectivelyPlaying => _isEffectivelyPlaying;

  // Timer để cập nhật position
  Timer? _positionTimer;

  /// Lần phát gần nhất dùng URL remote (để tải nền vào stream cache khi dừng / phát xong).
  bool _playedFromRemote = false;

  /// Đã lên lịch hoặc hoàn tất tải stream cache cho episodeId (tránh trùng).
  final Set<String> _streamCacheScheduledOrDone = {};

  StreamSubscription<void>? _onPlayerCompleteSub;
  StreamSubscription<Duration>? _onPositionChangedSub;
  StreamSubscription<Duration>? _onDurationChangedSub;
  StreamSubscription<PlayerState>? _onPlayerStateChangedSub;
  bool _audioListenersAttached = false;
  DateTime? _lastNotificationProgressSync;
  static const Duration _notificationProgressInterval = Duration(seconds: 1);

  double _playbackRate = 1.0;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndsAt;
  Duration? _abRepeatStart;
  Duration? _abRepeatEnd;
  Duration? _pendingSeekPosition;
  DateTime? _lastProgressPersistAt;
  static const Duration _progressPersistInterval = Duration(seconds: 5);
  static const List<double> _playbackRates = [0.75, 1.0, 1.25];

  bool _autoPlayNextEnabled = false;
  bool _sleepAfterCurrentEpisode = false;
  bool _episodeCompleteHandling = false;
  bool _suppressEpisodeComplete = false;
  String? _loadingEpisodeId;
  Future<void> _playbackChain = Future<void>.value();

  Duration _lastAdvCheckPosition = Duration.zero;
  bool _positionIsAdvancing = false;
  bool _iosRecordingSessionActive = false;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  bool get _isEffectivelyPlaying {
    if (_playerState == AudioPlayerState.paused) return false;
    if (_playerState == AudioPlayerState.playing) return true;
    if (!_isIOS) return false;
    return _positionIsAdvancing;
  }

  Future<T> _runPlaybackTask<T>(Future<T> Function() task) {
    final run = _playbackChain.then((_) => task());
    _playbackChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  double get playbackRate => _playbackRate;
  List<double> get availablePlaybackRates => _playbackRates;
  DateTime? get sleepTimerEndsAt => _sleepTimerEndsAt;
  bool get sleepAfterCurrentEpisode => _sleepAfterCurrentEpisode;
  bool get hasActiveSleepTimer =>
      _sleepTimerEndsAt != null || _sleepAfterCurrentEpisode;
  bool get autoPlayNextEnabled => _autoPlayNextEnabled;
  Duration? get abRepeatStart => _abRepeatStart;
  Duration? get abRepeatEnd => _abRepeatEnd;
  bool get hasAbRepeat => _abRepeatStart != null && _abRepeatEnd != null;
  bool get hasAbPointA => _abRepeatStart != null;
  bool get hasAbPointB => _abRepeatEnd != null;

  AudioContext _playbackAudioContext() => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
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
      );

  AudioContext _iosRecordingAudioContext() => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );

  AudioPlayerState? _mapNativeState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        return AudioPlayerState.playing;
      case PlayerState.paused:
        return AudioPlayerState.paused;
      case PlayerState.stopped:
      case PlayerState.completed:
        return AudioPlayerState.stopped;
      default:
        return null;
    }
  }

  Future<void> _reconcilePlayerState({bool notify = true}) async {
    if (!_isIOS) return;
    try {
      final mapped = _mapNativeState(_audioPlayer.state);
      if (mapped == null || mapped == _playerState) return;
      if (mapped == AudioPlayerState.stopped &&
          (_positionIsAdvancing || _playerState == AudioPlayerState.playing)) {
        return;
      }
      _playerState = mapped;
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('reconcilePlayerState: $e');
    }
  }

  Future<bool> _isNativePlaying() async {
    if (!_isIOS) return _playerState == AudioPlayerState.playing;
    try {
      return _audioPlayer.state == PlayerState.playing;
    } catch (_) {
      return _playerState == AudioPlayerState.playing || _positionIsAdvancing;
    }
  }

  void _trackPositionAdvance(Duration position) {
    if (!_isIOS) return;
    if (_playerState == AudioPlayerState.paused) {
      _positionIsAdvancing = false;
      return;
    }
    _positionIsAdvancing = position > _lastAdvCheckPosition;
    _lastAdvCheckPosition = position;
  }

  Future<void> _updatePlaybackNotification(bool isPlaying) async {
    if (_currentEpisode == null) return;
    await _notificationService.updateNotification(
      _currentEpisode!,
      isPlaying,
      duration: _totalDuration.inMilliseconds,
      currentPosition: _currentPosition.inMilliseconds,
    );
  }

  void _applyLegacyPlayerStateChange(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        _playerState = AudioPlayerState.playing;
        break;
      case PlayerState.paused:
        _playerState = AudioPlayerState.paused;
        break;
      case PlayerState.stopped:
        if (_playerState == AudioPlayerState.loading) break;
        _playerState = AudioPlayerState.stopped;
        _currentPosition = Duration.zero;
        break;
      case PlayerState.completed:
        if (_playerState == AudioPlayerState.loading) break;
        _playerState = AudioPlayerState.stopped;
        _currentPosition = Duration.zero;
        break;
      default:
        break;
    }
  }

  void _applyIosPlayerStateChange(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        _playerState = AudioPlayerState.playing;
        break;
      case PlayerState.paused:
        _playerState = AudioPlayerState.paused;
        _positionIsAdvancing = false;
        break;
      case PlayerState.stopped:
      case PlayerState.completed:
        if (_playerState == AudioPlayerState.loading) break;
        if (_positionIsAdvancing) break;
        _playerState = AudioPlayerState.stopped;
        _positionIsAdvancing = false;
        if (state == PlayerState.completed) {
          _currentPosition = Duration.zero;
        }
        break;
      default:
        break;
    }
  }

  /// Initialize service
  Future<void> initialize() async {
    await _userService.initialize();

    _notificationService.setMediaActionCallback(_handleNotificationMediaAction);
    _notificationService.setNotificationTapCallback(_handleNotificationTap);
    await _notificationService.initialize();

    _onPlayerCompleteSub ??= _audioPlayer.onPlayerComplete.listen((_) {
      unawaited(_handleEpisodeCompleted());
    });

    // Cấu hình AudioContext cho background playback
    try {
      await _audioPlayer.setAudioContext(_playbackAudioContext());
    } catch (e) {
      debugPrint('initialize setAudioContext: $e');
    }
  }

  /// Chuẩn bị audio session cho ghi âm (iOS-only).
  Future<void> prepareForRecording() async {
    if (!_isIOS) return;
    final audioWasActive = _isEffectivelyPlaying ||
        _playerState == AudioPlayerState.playing;
    if (audioWasActive) {
      await pause();
    }
    _positionIsAdvancing = false;
    notifyListeners();

    if (!audioWasActive) return;

    try {
      await _audioPlayer.setAudioContext(_iosRecordingAudioContext());
      _iosRecordingSessionActive = true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } catch (e) {
      debugPrint('prepareForRecording: $e');
    }
  }

  /// Khôi phục audio session phát nhạc sau ghi âm (iOS-only).
  Future<void> restoreAfterRecording() async {
    if (!_isIOS || !_iosRecordingSessionActive) return;
    _iosRecordingSessionActive = false;
    try {
      await _audioPlayer.setAudioContext(_playbackAudioContext());
    } catch (e) {
      debugPrint('restoreAfterRecording: $e');
    }
  }

  void setPendingSeekPosition(Duration position) {
    _pendingSeekPosition = position;
  }

  Future<void> setPlaybackRate(double rate) async {
    if (!_playbackRates.contains(rate)) return;
    _playbackRate = rate;
    try {
      await _audioPlayer.setPlaybackRate(rate);
    } catch (e) {
      debugPrint('setPlaybackRate error: $e');
    }
    notifyListeners();
  }

  Future<void> cyclePlaybackRate() async {
    final idx = _playbackRates.indexOf(_playbackRate);
    final next = _playbackRates[(idx + 1) % _playbackRates.length];
    await setPlaybackRate(next);
  }

  void resetAutoPlayNext() {
    if (!_autoPlayNextEnabled) return;
    _autoPlayNextEnabled = false;
    notifyListeners();
  }

  void toggleAutoPlayNext() {
    _autoPlayNextEnabled = !_autoPlayNextEnabled;
    notifyListeners();
  }

  void clearSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    _sleepAfterCurrentEpisode = false;
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepAfterCurrentEpisode = false;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    if (duration == null) {
      notifyListeners();
      return;
    }
    _sleepTimerEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () async {
      await _stopForSleepTimer();
    });
    notifyListeners();
  }

  Future<void> _stopForSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    notifyListeners();

    if (_isIOS) {
      try {
        final native = _audioPlayer.state;
        if (native == PlayerState.playing) {
          await _audioPlayer.pause();
        }
      } catch (e) {
        debugPrint('_stopForSleepTimer iOS: $e');
      }
      _playerState = AudioPlayerState.paused;
      _positionIsAdvancing = false;
      notifyListeners();
      await _persistListeningProgress();
      await _updatePlaybackNotification(false);
      await _reconcilePlayerState();
      return;
    }
    await pause();
  }

  void setSleepAfterCurrentEpisode() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    _sleepAfterCurrentEpisode = true;
    notifyListeners();
  }

  Future<void> _handleEpisodeCompleted() async {
    if (_suppressEpisodeComplete || _episodeCompleteHandling) return;
    _episodeCompleteHandling = true;
    _suppressEpisodeComplete = true;
    try {
      _scheduleBackgroundStreamCacheIfNeeded();
      final ep = _currentEpisode;
      if (ep != null && _totalDuration.inMilliseconds > 0) {
        await _learningProgress.updateListeningProgress(
          episode: ep,
          positionMs: _totalDuration.inMilliseconds,
          totalDurationMs: _totalDuration.inMilliseconds,
        );
      }

      if (_sleepAfterCurrentEpisode) {
        _sleepAfterCurrentEpisode = false;
        notifyListeners();
        if (_isIOS) {
          await _stopForSleepTimer();
        } else {
          _playerState = AudioPlayerState.stopped;
          notifyListeners();
        }
        if (_currentEpisode != null) {
          await _notificationService.updateNotification(
            _currentEpisode!,
            false,
            duration: _totalDuration.inMilliseconds,
            currentPosition: _totalDuration.inMilliseconds,
          );
        }
        return;
      }

      if (_autoPlayNextEnabled &&
          !hasAbRepeat &&
          _currentEpisodeIndex < _currentCategoryEpisodes.length - 1) {
        clearAbRepeat();
        final nextEpisode =
            _currentCategoryEpisodes[_currentEpisodeIndex + 1];
        await loadEpisodeWithCategory(nextEpisode, _currentCategoryEpisodes);
        if (_currentEpisode?.id != nextEpisode.id) return;
        _applySavedSeekForEpisode(nextEpisode);
        await play();
      }
    } finally {
      _episodeCompleteHandling = false;
      _suppressEpisodeComplete = false;
    }
  }

  void _applySavedSeekForEpisode(Episode episode) {
    final saved = _learningProgress.getProgressForEpisode(episode);
    if (saved != null &&
        saved.lastPositionMs > 0 &&
        !saved.listenedComplete &&
        !_isNearEndPosition(saved.lastPositionMs, saved.totalDurationMs)) {
      setPendingSeekPosition(Duration(milliseconds: saved.lastPositionMs));
    } else {
      _pendingSeekPosition = null;
    }
  }

  bool _isNearEndPosition(int positionMs, int totalDurationMs) {
    if (totalDurationMs <= 0) return false;
    return positionMs >= (totalDurationMs * 0.92).round();
  }

  bool _isActiveEpisodeLoad(String episodeId) => _loadingEpisodeId == episodeId;

  void setAbRepeat({Duration? start, Duration? end}) {
    if (start == null || end == null || end <= start) {
      clearAbRepeat();
      return;
    }
    _abRepeatStart = start;
    _abRepeatEnd = end;
    notifyListeners();
  }

  void clearAbRepeat() {
    _abRepeatStart = null;
    _abRepeatEnd = null;
    notifyListeners();
  }

  void markAbPointA() {
    _abRepeatStart = _currentPosition;
    if (_abRepeatEnd != null && _abRepeatEnd! <= _abRepeatStart!) {
      _abRepeatEnd = null;
    }
    notifyListeners();
  }

  void markAbPointB() {
    if (_abRepeatStart == null) {
      markAbPointA();
    }
    _abRepeatEnd = _currentPosition;
    if (_abRepeatEnd! <= _abRepeatStart!) {
      _abRepeatEnd = _abRepeatStart! + const Duration(seconds: 5);
    }
    notifyListeners();
  }

  Future<void> _persistListeningProgress() async {
    final ep = _currentEpisode;
    if (ep == null) return;
    final now = DateTime.now();
    if (_lastProgressPersistAt != null &&
        now.difference(_lastProgressPersistAt!) < _progressPersistInterval) {
      return;
    }
    _lastProgressPersistAt = now;
    await _learningProgress.updateListeningProgress(
      episode: ep,
      positionMs: _currentPosition.inMilliseconds,
      totalDurationMs: _totalDuration.inMilliseconds,
    );
  }

  /// Load episode và category episodes
  Future<void> loadEpisode(Episode episode) async {
    _scheduleBackgroundStreamCacheIfNeeded();
    _playedFromRemote = false;
    _currentEpisode = episode;
    _playerState = AudioPlayerState.stopped;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;

    _currentAudioUrl = await _resolvePlaybackUrl(episode);
    
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
  Future<void> loadEpisodeWithCategory(
    Episode episode,
    List<Episode> categoryEpisodes,
  ) {
    return _runPlaybackTask(() async {
      final episodeId = episode.id ?? '';
      final isEpisodeChange = _currentEpisode?.id != episode.id;
      _loadingEpisodeId = episodeId;
      _suppressEpisodeComplete = true;

      if (isEpisodeChange) {
        _scheduleBackgroundStreamCacheIfNeeded();
        _playedFromRemote = false;
        _playerState = AudioPlayerState.stopped;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        await _audioPlayer.stop();
      }

      try {
        if (!_isActiveEpisodeLoad(episodeId)) return;

        _currentEpisode = episode;
        _currentCategoryEpisodes = categoryEpisodes;
        _currentEpisodeIndex =
            categoryEpisodes.indexWhere((e) => e.id == episode.id);

        if (_currentEpisodeIndex == -1) {
          _currentEpisodeIndex = 0;
        }

        _currentAudioUrl = await _resolvePlaybackUrl(episode);
        if (!_isActiveEpisodeLoad(episodeId)) return;

        _isFavourite = await _checkFavouriteStatus(episode.id ?? '');
        if (!_isActiveEpisodeLoad(episodeId)) return;

        _isDownloaded = await _checkDownloadStatus(episode.id ?? '');
        if (!_isActiveEpisodeLoad(episodeId)) return;

        notifyListeners();
      } finally {
        if (_isActiveEpisodeLoad(episodeId)) {
          _loadingEpisodeId = null;
        }
        if (!_episodeCompleteHandling) {
          _suppressEpisodeComplete = false;
        }
      }
    });
  }

  /// Cập nhật metadata episode đang phát mà không dừng audio.
  Future<void> refreshEpisodeData(Episode episode) async {
    final episodeId = episode.id ?? '';
    if (episodeId.isEmpty || _currentEpisode?.id != episodeId) return;

    _currentEpisode = episode;
    final index = _currentCategoryEpisodes.indexWhere((e) => e.id == episodeId);
    if (index != -1) {
      _currentCategoryEpisodes[index] = episode;
    }

    final resolved = await _resolvePlaybackUrl(episode);
    if (resolved != null) {
      _currentAudioUrl = resolved;
    }

    _isFavourite = await _checkFavouriteStatus(episodeId);
    _isDownloaded = await _checkDownloadStatus(episodeId);
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

  /// Thứ tự: file local trong episode → downloads/ → audio_stream_cache/ → remote.
  Future<String?> _resolvePlaybackUrl(Episode episode) async {
    final id = episode.id ?? '';
    if (kIsWeb) {
      final direct = _getAudioUrl(episode);
      if (direct != null && _isRemoteUrl(direct)) {
        debugLogDataSource(
          'Audio',
          'episodeId=$id | Source: web remote direct URL | ${_truncateForLog(direct)}',
        );
        return direct;
      }
      final remote = _getRemoteAudioUrl(episode);
      debugLogDataSource(
        'Audio',
        'episodeId=$id | Source: web remote fallback URL | ${_truncateForLog(remote)}',
      );
      return remote;
    }

    final direct = _getAudioUrl(episode);
    if (direct != null && !_isRemoteUrl(direct)) {
      if (await _downloadService.fileExists(direct)) {
        debugLogDataSource(
          'Audio',
          'episodeId=$id | Source: local path in Episode (fileUrl) | $direct',
        );
        return direct;
      }
    }
    if (id.isNotEmpty) {
      final manual = await _downloadService.downloadedEpisodePathIfExists(id);
      if (manual != null) {
        debugLogDataSource(
          'Audio',
          'episodeId=$id | Source: downloads folder (manual download) | $manual',
        );
        return manual;
      }
      final stream = await _downloadService.streamCachedEpisodePathIfExists(id);
      if (stream != null) {
        debugLogDataSource(
          'Audio',
          'episodeId=$id | Source: audio_stream_cache (after stream) | $stream',
        );
        return stream;
      }
    }
    final remote = _getRemoteAudioUrl(episode);
    debugLogDataSource(
      'Audio',
      'episodeId=$id | Source: remote HTTP (Storage/API URL) | ${_truncateForLog(remote)}',
    );
    return remote;
  }

  String _truncateForLog(String? s, [int max = 96]) {
    if (s == null || s.isEmpty) return '(null)';
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }

  void _scheduleBackgroundStreamCacheIfNeeded() {
    if (kIsWeb) return;
    if (!_playedFromRemote) return;
    final ep = _currentEpisode;
    final id = ep?.id;
    if (id == null || id.isEmpty) return;
    if (_streamCacheScheduledOrDone.contains(id)) return;
    final remote = _getRemoteAudioUrl(ep!);
    if (remote == null) return;
    _streamCacheScheduledOrDone.add(id);
    unawaited(_runBackgroundStreamCache(episodeId: id, remoteUrl: remote));
  }

  Future<void> _runBackgroundStreamCache({
    required String episodeId,
    required String remoteUrl,
  }) async {
    try {
      if (await _downloadService.downloadedEpisodePathIfExists(episodeId) != null) {
        return;
      }
      if (await _downloadService.streamCachedEpisodePathIfExists(episodeId) != null) {
        return;
      }
      debugLogDataSource(
        'Audio',
        'episodeId=$episodeId | Background download → audio_stream_cache (after stream) | ${_truncateForLog(remoteUrl)}',
      );
      final path = await _downloadService.downloadToStreamCache(
        url: remoteUrl,
        episodeId: episodeId,
      );
      if (path == null) {
        _streamCacheScheduledOrDone.remove(episodeId);
      } else {
        debugLogDataSource(
          'Audio',
          'episodeId=$episodeId | Stream cache saved | $path',
        );
      }
    } catch (_) {
      _streamCacheScheduledOrDone.remove(episodeId);
    }
  }

  /// Play audio
  Future<void> play() {
    return _runPlaybackTask(() async {
      if (_currentEpisode == null) {
        debugPrint('No episode or audio URL available');
        return;
      }

      _playerState = AudioPlayerState.loading;
      notifyListeners();

      try {
        final resolved = await _resolvePlaybackUrl(_currentEpisode!);
        if (resolved == null) {
          _playerState = AudioPlayerState.stopped;
          notifyListeners();
          return;
        }
        _currentAudioUrl = resolved;
        _playedFromRemote = _isRemoteUrl(resolved);

        _setupAudioPlayerListeners();

        final source = _buildAudioSource(_currentAudioUrl!);
        await _audioPlayer.play(source);
        await _audioPlayer.setPlaybackRate(_playbackRate);

        if (_pendingSeekPosition != null) {
          await seekTo(_pendingSeekPosition!);
          _pendingSeekPosition = null;
        }

        _playerState = AudioPlayerState.playing;
        _positionIsAdvancing = false;
        _lastAdvCheckPosition = _currentPosition;
        notifyListeners();
        if (_isIOS) {
          unawaited(_reconcilePlayerState());
        }

        if (_currentEpisode != null) {
          await _notificationService.showAudioNotification(
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
    });
  }

  /// Setup audio player listeners
  void _setupAudioPlayerListeners() {
    if (_audioListenersAttached) return;
    _audioListenersAttached = true;

    _onPositionChangedSub ??= _audioPlayer.onPositionChanged.listen((Duration position) {
      _trackPositionAdvance(position);
      _currentPosition = position;
      notifyListeners();
      _syncNotificationProgressIfNeeded();
      _handleAbRepeatLoop(position);
      unawaited(_persistListeningProgress());
    });

    _onDurationChangedSub ??= _audioPlayer.onDurationChanged.listen((Duration duration) {
      _totalDuration = duration;
      notifyListeners();
      _syncNotificationProgressIfNeeded(force: true);
    });

    _onPlayerStateChangedSub ??= _audioPlayer.onPlayerStateChanged.listen((PlayerState state) async {
      if (_isIOS) {
        _applyIosPlayerStateChange(state);
      } else {
        _applyLegacyPlayerStateChange(state);
      }
      notifyListeners();

      if (_currentEpisode != null) {
        await _updatePlaybackNotification(
          _playerState == AudioPlayerState.playing,
        );
      }
    });
  }

  /// Toggle play/pause — xử lý desync native state trên iOS.
  Future<void> togglePlayPause({Future<void> Function()? onPlayPressed}) async {
    if (isLoading) return;

    if (isPaused) {
      await resume();
      return;
    }
    if (isPlaying || (_isIOS && _positionIsAdvancing)) {
      await pause();
      return;
    }

    if (_isIOS) {
      try {
        final native = _audioPlayer.state;
        if (native == PlayerState.playing) {
          await pause();
          return;
        }
        if (native == PlayerState.paused) {
          await resume();
          return;
        }
      } catch (e) {
        debugPrint('togglePlayPause iOS state check: $e');
      }
    }

    await onPlayPressed?.call();
    await play();
  }

  /// Pause audio
  Future<void> pause() async {
    if (_isIOS) {
      final shouldPause = _playerState == AudioPlayerState.playing ||
          _positionIsAdvancing ||
          await _isNativePlaying();
      if (!shouldPause) return;

      return _runPlaybackTask(() async {
        await _audioPlayer.pause();
        _playerState = AudioPlayerState.paused;
        _positionIsAdvancing = false;
        notifyListeners();
        await _persistListeningProgress();
        await _updatePlaybackNotification(false);
      });
    }

    if (_playerState == AudioPlayerState.playing) {
      await _audioPlayer.pause();
      _playerState = AudioPlayerState.paused;
      notifyListeners();
      await _persistListeningProgress();
      await _updatePlaybackNotification(false);
    }
  }

  /// Resume audio
  Future<void> resume() async {
    if (_isIOS) {
      final shouldResume = _playerState == AudioPlayerState.paused;
      if (!shouldResume) {
        try {
          if (_audioPlayer.state != PlayerState.paused) return;
        } catch (_) {
          return;
        }
      }
      await _audioPlayer.resume();
      _playerState = AudioPlayerState.playing;
      notifyListeners();
      await _updatePlaybackNotification(true);
      return;
    }

    if (_playerState == AudioPlayerState.paused) {
      await _audioPlayer.resume();
      _playerState = AudioPlayerState.playing;
      notifyListeners();
      await _updatePlaybackNotification(true);
    }
  }

  /// Stop audio
  Future<void> stop() {
    return _runPlaybackTask(() async {
      _scheduleBackgroundStreamCacheIfNeeded();
      await _audioPlayer.stop();
      _playerState = AudioPlayerState.stopped;
      _currentPosition = Duration.zero;
      notifyListeners();

      await _notificationService.hideNotification();
    });
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

      final existingDownload = await _downloadService.downloadedEpisodePathIfExists(episodeId);
      if (existingDownload != null) {
        debugLogDataSource(
          'Download',
          'episodeId=$episodeId | File already in downloads — DB update only | $existingDownload',
        );
        final updatedEpisode = _copyEpisodeWithFileUrl(episode, existingDownload);
        await _localDatabaseService.upsertEpisode(updatedEpisode);
        _updateCurrentEpisode(updatedEpisode);
        _currentAudioUrl = await _resolvePlaybackUrl(updatedEpisode);
        _isDownloaded = true;
        notifyListeners();
        return;
      }

      final promoted = await _downloadService.promoteStreamCacheToDownload(episodeId);
      if (promoted != null) {
        debugLogDataSource(
          'Download',
          'episodeId=$episodeId | Promote audio_stream_cache → downloads (no re-download) | $promoted',
        );
        final updatedEpisode = _copyEpisodeWithFileUrl(episode, promoted);
        await _localDatabaseService.upsertEpisode(updatedEpisode);
        _updateCurrentEpisode(updatedEpisode);
        _currentAudioUrl = await _resolvePlaybackUrl(updatedEpisode);
        _isDownloaded = true;
        notifyListeners();
        return;
      }

      final remoteUrl = _getRemoteAudioUrl(episode);
      if (remoteUrl == null) return;

      debugLogDataSource(
        'Download',
        'episodeId=$episodeId | Download from network → downloads | ${_truncateForLog(remoteUrl)}',
      );
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
      return await _storageService.isEpisodeFavourite(episodeId);
    } catch (e) {
      debugPrint('Error checking favourite status: $e');
      return false;
    }
  }

  /// Save favourite status
  Future<void> _saveFavouriteStatus(String episodeId, bool isFavourite) async {
    try {
      if (isFavourite) {
        if (_currentEpisode != null) {
          await _storageService.addFavouriteEpisode(_currentEpisode!);
        }
      } else {
        await _storageService.removeFavouriteEpisode(episodeId);
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
      _currentAudioUrl = await _resolvePlaybackUrl(updatedEpisode);
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
        debugPrint('App paused/inactive - audio continues playing in background');
        break;
      case AppLifecycleState.resumed:
        debugPrint('App resumed - audio continues playing');
        break;
      case AppLifecycleState.detached:
        stop();
        break;
      case AppLifecycleState.hidden:
        debugPrint('App hidden - audio continues playing in background');
        break;
    }
  }

  void _handleNotificationMediaAction(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    switch (action) {
      case 'action_play':
        unawaited(_handleMediaPlay());
        break;
      case 'action_pause':
        if (isPlaying) {
          unawaited(pause());
        }
        break;
      case 'action_toggle_play_pause':
        unawaited(_handleMediaPlayPauseToggle());
        break;
      case 'action_skip_forward':
        unawaited(skipForward());
        break;
      case 'action_skip_backward':
        unawaited(skipBackward());
        break;
      case 'action_seek':
        final seekToRaw = data['seek_to'];
        final seekToMs = seekToRaw is int
            ? seekToRaw
            : (seekToRaw is num ? seekToRaw.toInt() : null);
        if (seekToMs != null && seekToMs >= 0) {
          unawaited(seekTo(Duration(milliseconds: seekToMs)));
        }
        break;
    }
  }

  void _syncNotificationProgressIfNeeded({bool force = false}) {
    if (_currentEpisode == null) return;
    if (!isPlaying && !isPaused) return;
    if (_totalDuration.inMilliseconds <= 0 && !force) return;

    final now = DateTime.now();
    if (!force &&
        _lastNotificationProgressSync != null &&
        now.difference(_lastNotificationProgressSync!) <
            _notificationProgressInterval) {
      return;
    }
    _lastNotificationProgressSync = now;

    unawaited(
      _notificationService.updateNotification(
        _currentEpisode!,
        isPlaying,
        duration: _totalDuration.inMilliseconds,
        currentPosition: _currentPosition.inMilliseconds,
      ),
    );
  }

  void _handleNotificationTap(String episodeId, String? category) {
    unawaited(
      MediaNotificationLaunchHandler.openEpisodeFromNotification(
        episodeId: episodeId,
        category: category,
      ),
    );
  }

  Future<void> _handleMediaPlay() async {
    if (isPaused) {
      await resume();
    } else if (!isPlaying) {
      await play();
    }
  }

  Future<void> _handleMediaPlayPauseToggle() async {
    await togglePlayPause();
  }

  void _handleAbRepeatLoop(Duration position) {
    final end = _abRepeatEnd;
    final start = _abRepeatStart;
    if (end == null || start == null) return;
    if (!_isEffectivelyPlaying) return;
    if (position >= end) {
      unawaited(seekTo(start));
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _sleepTimer?.cancel();
    _onPlayerCompleteSub?.cancel();
    _onPositionChangedSub?.cancel();
    _onDurationChangedSub?.cancel();
    _onPlayerStateChangedSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
