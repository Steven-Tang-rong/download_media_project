import 'package:flutter/material.dart';
import 'package:funday_download_media_project/model/audio_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:funday_download_media_project/utils/file_utils.dart';
import 'dart:io';

enum AudioPlayerState {
  loading,
  playing,
  paused,
  error,
}

class AudioPlayerStateData {
  final AudioPlayerState state;
  final String? errorMessage;

  const AudioPlayerStateData({
    required this.state,
    this.errorMessage,
  });
}

class AudioPlayerPage extends StatefulWidget {
  final AudioItem audioItem;
  final String filePath;

  const AudioPlayerPage({
    super.key,
    required this.audioItem,
    required this.filePath,
  });

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late AudioPlayer _audioPlayer;
  AudioPlayerStateData _playerState = const AudioPlayerStateData(state: AudioPlayerState.loading);
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      final File audioFile = File(widget.filePath);
      if (!await audioFile.exists()) {
        setState(() {
          _playerState = const AudioPlayerStateData(
            state: AudioPlayerState.error,
            errorMessage: '音檔不存在',
          );
        });
        return;
      }

      await _audioPlayer.setFilePath(widget.filePath);

      _audioPlayer.playingStream.listen((playing) {
        if (mounted) {
          setState(() {
            _playerState = AudioPlayerStateData(
              state: playing ? AudioPlayerState.playing : AudioPlayerState.paused,
            );
          });
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _duration = duration;
            if (_playerState.state == AudioPlayerState.loading) {
              _playerState = const AudioPlayerStateData(state: AudioPlayerState.paused);
            }
          });
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _playerState = const AudioPlayerStateData(state: AudioPlayerState.paused);
            _position = Duration.zero;
          });
        }
      });
    } catch (e) {
      setState(() {
        _playerState = AudioPlayerStateData(
          state: AudioPlayerState.error,
          errorMessage: '載入音檔失敗: $e',
        );
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_playerState.state == AudioPlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放錯誤: $e')),
        );
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('跳轉失敗: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'FUNDAY',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade500,
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_playerState.state == AudioPlayerState.loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('載入音檔中...'),
          ],
        ),
      );
    }

    if (_playerState.state == AudioPlayerState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _playerState.errorMessage ?? '未知錯誤',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Text(
                  '{${getDisplayFileName(widget.filePath)}}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.audioItem.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            child: IconButton(
              icon: Icon(
                _playerState.state == AudioPlayerState.playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
              onPressed: _togglePlayPause,
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds.toDouble()
                    : 0.0,
                max: _duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  final position = Duration(milliseconds: value.toInt());
                  _seekTo(position);
                },
                activeColor: Colors.black,
                inactiveColor: Colors.grey.shade300,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
