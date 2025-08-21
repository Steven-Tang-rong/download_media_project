import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadManager {
  static final Dio _dio = Dio();

  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

        // Android 13+ (API 33+)
        if (androidInfo.version.sdkInt >= 33) {
          var status = await Permission.audio.status;
          if (!status.isGranted) {
            status = await Permission.audio.request();
          }
          return status.isGranted;
        } else {
          // Android 12
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          return status.isGranted;
        }
      } catch (e) {
        var audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          audioStatus = await Permission.audio.request();
        }
        if (audioStatus.isGranted) return true;

        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
        }
        return storageStatus.isGranted;
      }
    }
    return true;
  }

  static String _getFileNameFromUrl(String url, int audioId) {
    try {
      Uri uri = Uri.parse(url);
      String fileName = path.basename(uri.path);

      if (fileName.isEmpty || !fileName.contains('.')) {
        fileName = 'audio_$audioId.mp3';
      }

      return fileName;
    } catch (e) {
      return 'audio_$audioId.mp3';
    }
  }

  static Future<DownloadResult> downloadAudioFile({
    required String url,
    required int audioId,
    required String title,
    Function(double progress)? onProgress,
  }) async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return DownloadResult.error('儲存權限被拒絕');
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory audioDir = Directory('${appDocDir.path}/audio');

      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final String fileName = _getFileNameFromUrl(url, audioId);
      final String filePath = '${audioDir.path}/$fileName';

      final File file = File(filePath);
      if (await file.exists()) {
        return DownloadResult.success(filePath, fileName);
      }

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            onProgress(progress);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          return DownloadResult.success(filePath, fileName);
        } else {
          await file.delete();
          return DownloadResult.error('下載的檔案為空');
        }
      } else {
        return DownloadResult.error('檔案下載失敗');
      }
    } on DioException catch (e) {
      String errorMsg = '下載失敗';
      return DownloadResult.error(errorMsg);
    } catch (e) {
      return DownloadResult.error('下載失敗: $e');
    }
  }

  static Future<String?> getDownloadedFilePath(int audioId) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory audioDir = Directory('${appDocDir.path}/audio');

      if (!await audioDir.exists()) {
        return null;
      }

      final List<FileSystemEntity> files = await audioDir.list().toList();

      for (FileSystemEntity entity in files) {
        if (entity is File) {
          final String fileName = path.basename(entity.path);
          if (fileName.startsWith('audio_$audioId.') ||
              fileName.contains('_$audioId.')) {
            return entity.path;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

class DownloadResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final String? errorMessage;

  DownloadResult._({
    required this.success,
    this.filePath,
    this.fileName,
    this.errorMessage,
  });

  factory DownloadResult.success(String filePath, String fileName) {
    return DownloadResult._(
      success: true,
      filePath: filePath,
      fileName: fileName,
    );
  }

  factory DownloadResult.error(String errorMessage) {
    return DownloadResult._(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class DownloadedFileInfo {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime downloadDate;

  DownloadedFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.downloadDate,
  });
}
