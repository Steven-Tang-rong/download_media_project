import 'package:flutter/material.dart';
import 'package:funday_download_media_project/audio_provider.dart';
import 'package:funday_download_media_project/model/audio_model.dart';
import 'package:funday_download_media_project/page/audio_play_page.dart';
import 'package:funday_download_media_project/utils/date_formatter.dart';
import 'package:provider/provider.dart';

enum AudioButtonState {
  downloading,
  downloaded,
  notDownloaded,
}

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final provider = Provider.of<AudioProvider>(context, listen: false);

        if (!provider.isLoading &&
            !provider.isLoadingMore &&
            provider.hasMoreData) {
          provider.loadMoreAudio();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade500,
            height: 1.0,
          ),
        ),
      ),
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          return RefreshIndicator(
            onRefresh: () => audioProvider.refreshAudio(),
            child: _buildBody(audioProvider),
          );
        },
      ),
    );
  }

  Widget _buildBody(AudioProvider audioProvider) {
    if (audioProvider.isLoading && !audioProvider.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (audioProvider.errorMessage != null && !audioProvider.hasData) {
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
              audioProvider.errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => audioProvider.loadAudio(refresh: true),
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    final totalItems = audioProvider.audioList.length +
        (audioProvider.isLoadingMore ? 1 : 0) +
        (!audioProvider.hasMoreData && audioProvider.hasData ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: totalItems * 2 - 1,
      itemBuilder: (context, index) {
        if (index.isOdd) {
          final itemIndex = index ~/ 2;
          if (itemIndex >= audioProvider.audioList.length) {
            return const SizedBox.shrink();
          }
          return Container(
            height: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          );
        }

        final actualIndex = index ~/ 2;
        if (actualIndex == audioProvider.audioList.length &&
            audioProvider.isLoadingMore) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  '載入資料中...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        if (actualIndex == audioProvider.audioList.length &&
            !audioProvider.hasMoreData &&
            audioProvider.hasData) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.grey.shade500,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '已載入所有資料',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final audioItem = audioProvider.audioList[actualIndex];
        final isDownloaded = audioProvider.isAudioDownloaded(audioItem.id);
        final isDownloading = audioProvider.isAudioDownloading(audioItem.id);

        return mediaTile(
          audioItem.title,
          audioItem.modifiedDateTime,
          isDownloaded: isDownloaded,
          isDownloading: isDownloading,
          onDownload: () => _handleDownload(audioItem, audioProvider),
          onPlay: () => _handlePlay(audioItem, audioProvider),
        );
      },
    );
  }

  Widget mediaTile(
    String title,
    DateTime? modifiedDate, {
    required bool isDownloaded,
    required bool isDownloading,
    VoidCallback? onDownload,
    VoidCallback? onPlay,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildActionButton(
                state: _getButtonState(isDownloaded, isDownloading),
                onDownload: onDownload,
                onPlay: onPlay,
              ),
              const SizedBox(height: 8),
              Text(
                formatDate(modifiedDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AudioButtonState _getButtonState(bool isDownloaded, bool isDownloading) {
    if (isDownloading) {
      return AudioButtonState.downloading;
    } else if (isDownloaded) {
      return AudioButtonState.downloaded;
    } else {
      return AudioButtonState.notDownloaded;
    }
  }

  Widget _buildActionButton({
    required AudioButtonState state,
    VoidCallback? onDownload,
    VoidCallback? onPlay,
  }) {
    switch (state) {
      case AudioButtonState.downloading:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '下載中',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        );
      case AudioButtonState.downloaded:
        return OutlinedButton(
          onPressed: onPlay,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(80, 32),
            side: BorderSide(color: Colors.blue.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '播放',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        );
      case AudioButtonState.notDownloaded:
        return OutlinedButton(
          onPressed: onDownload,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(80, 32),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '下載',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
    }
  }

  void _handleDownload(AudioItem audioItem, AudioProvider audioProvider) {
    if (audioProvider.isAudioDownloaded(audioItem.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此音訊已下載')),
      );
      return;
    }

    if (audioProvider.isAudioDownloading(audioItem.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此音訊正在下載中')),
      );
      return;
    }

    _performDownload(audioItem, audioProvider);
  }

  void _handlePlay(AudioItem audioItem, AudioProvider audioProvider) {
    final String? filePath = audioProvider.getDownloadedFilePath(audioItem.id);

    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到音檔檔案')),
      );
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AudioPlayerPage(
          audioItem: audioItem,
          filePath: filePath,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _performDownload(
      AudioItem audioItem, AudioProvider audioProvider) async {
    try {
      final result = await audioProvider.downloadAudioFile(audioItem);

      if (result.success) {
        _showDownloadSuccessAnimation(audioItem.title);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '下載失敗'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下載錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDownloadSuccessAnimation(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '下載完成',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '「$title」已成功下載',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }
}
