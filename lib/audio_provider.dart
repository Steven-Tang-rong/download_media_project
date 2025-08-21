import 'package:flutter/material.dart';
import 'package:funday_download_media_project/api_service.dart';
import 'package:funday_download_media_project/download_manager.dart';
import 'package:funday_download_media_project/model/audio_model.dart';

enum AudioDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
}

enum LoadingState {
  idle,
  loading,
  loadingMore,
  error,
}

class AudioProvider extends ChangeNotifier {
  List<AudioItem> _audioList = [];
  LoadingState _loadingState = LoadingState.idle;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;

  final Map<int, String> _downloadedAudioFiles = <int, String>{};
  final Map<int, AudioDownloadStatus> _audioDownloadStatuses =
      <int, AudioDownloadStatus>{};

  List<AudioItem> get audioList => _audioList;
  LoadingState get loadingState => _loadingState;
  bool get isLoading => _loadingState == LoadingState.loading;
  bool get isLoadingMore => _loadingState == LoadingState.loadingMore;
  bool get hasError => _loadingState == LoadingState.error;
  String? get errorMessage => _errorMessage;
  bool get hasData => _audioList.isNotEmpty;
  bool get hasMoreData => _hasMoreData;

  AudioDownloadStatus getAudioDownloadStatus(int audioId) {
    return _audioDownloadStatuses[audioId] ?? AudioDownloadStatus.notDownloaded;
  }

  bool isAudioDownloaded(int audioId) {
    return getAudioDownloadStatus(audioId) == AudioDownloadStatus.downloaded;
  }

  bool isAudioDownloading(int audioId) {
    return getAudioDownloadStatus(audioId) == AudioDownloadStatus.downloading;
  }

  String? getDownloadedFilePath(int audioId) {
    return _downloadedAudioFiles[audioId];
  }

  Future<void> _checkExistingDownloads() async {
    for (final audio in _audioList) {
      final String? filePath =
          await DownloadManager.getDownloadedFilePath(audio.id);
      if (filePath != null) {
        _downloadedAudioFiles[audio.id] = filePath;
        _audioDownloadStatuses[audio.id] = AudioDownloadStatus.downloaded;
      } else {
        _audioDownloadStatuses[audio.id] = AudioDownloadStatus.notDownloaded;
      }
    }
    notifyListeners();
  }

  Future<DownloadResult> downloadAudioFile(AudioItem audioItem) async {
    if (isAudioDownloaded(audioItem.id)) {
      return DownloadResult.error('此音訊已下載');
    }

    if (isAudioDownloading(audioItem.id)) {
      return DownloadResult.error('此音訊正在下載中');
    }

    _audioDownloadStatuses[audioItem.id] = AudioDownloadStatus.downloading;
    notifyListeners();

    try {
      final result = await DownloadManager.downloadAudioFile(
        url: audioItem.url,
        audioId: audioItem.id,
        title: audioItem.title,
      );

      if (result.success && result.filePath != null) {
        _downloadedAudioFiles[audioItem.id] = result.filePath!;
        _audioDownloadStatuses[audioItem.id] = AudioDownloadStatus.downloaded;
      } else {
        _audioDownloadStatuses[audioItem.id] =
            AudioDownloadStatus.notDownloaded;
      }

      notifyListeners();
      return result;
    } catch (e) {
      _audioDownloadStatuses[audioItem.id] = AudioDownloadStatus.notDownloaded;
      notifyListeners();
      return DownloadResult.error('下載失敗: $e');
    }
  }

  Future<void> loadAudio({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _audioList.clear();
      _hasMoreData = true;
      _downloadedAudioFiles.clear();
      _audioDownloadStatuses.clear();
    }

    _setLoading(true);
    _clearError();

    try {
      final results = await Future.wait([
        AudioApiService.getAudioList(page: _currentPage),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      final response = results[0] as AudioResponse;

      if (refresh) {
        _audioList = response.data;
      } else {
        _audioList.addAll(response.data);
      }

      if (response.data.isEmpty || _audioList.length >= response.total) {
        _hasMoreData = false;
      }

      await _checkExistingDownloads();

      _setLoading(false);
      notifyListeners();
    } on AudioApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('載入失敗: $e');
    }
  }

  Future<void> loadMoreAudio() async {
    if (isLoading || isLoadingMore || !_hasMoreData) return;

    _currentPage++;
    _setLoadingMore(true);

    try {
      final results = await Future.wait([
        AudioApiService.getAudioList(page: _currentPage),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      final response = results[0] as AudioResponse;

      if (response.data.isEmpty) {
        _hasMoreData = false;
        _currentPage--;
      } else {
        _audioList.addAll(response.data);
        if (_audioList.length >= response.total) {
          _hasMoreData = false;
        }
      }

      _setLoadingMore(false);
      notifyListeners();
    } on AudioApiException catch (e) {
      _currentPage--;
      _setLoadingMore(false);
      _setError('載入更多失敗: ${e.message}');
    } catch (e) {
      _currentPage--;
      _setLoadingMore(false);
      _setError('載入更多失敗: $e');
    }
  }

  Future<void> refreshAudio() async {
    await loadAudio(refresh: true);
  }

  void _setLoading(bool loading) {
    _loadingState = loading ? LoadingState.loading : LoadingState.idle;
    if (loading) {
      _clearError();
    }
    notifyListeners();
  }

  void _setLoadingMore(bool loadingMore) {
    _loadingState = loadingMore ? LoadingState.loadingMore : LoadingState.idle;
    if (loadingMore) {
      _clearError();
    }
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _loadingState = LoadingState.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
