import 'dart:convert';
import 'package:funday_download_media_project/model/audio_model.dart';
import 'package:http/http.dart' as http;

class AudioApiService {
  static const String _baseUrl =
      'https://www.travel.taipei/open-api/zh-tw/Media/Audio';

  static Future<AudioResponse> getAudioList({int page = 1}) async {
    try {
      final uri = Uri.parse('$_baseUrl?page=$page');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> jsonData = json.decode(utf8Body);

        return AudioResponse.fromJson(jsonData);
      } else {
        throw AudioApiException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw AudioApiException('網路連線錯誤: ${e.message}', 0);
    } on FormatException catch (e) {
      throw AudioApiException('資料格式錯誤: ${e.message}', 0);
    } catch (e) {
      throw AudioApiException('未知錯誤: $e', 0);
    }
  }

  static Future<List<AudioItem>> searchAudio({
    required String keyword,
  }) async {
    List<AudioItem> searchResults = [];
    int page = 1;

    while (true) {
      try {
        final response = await getAudioList(page: page);

        if (response.data.isEmpty) {
          break;
        }

        final filtered = response.data
            .where((audio) =>
                audio.title.contains(keyword) ||
                (audio.summary != null && audio.summary!.contains(keyword)))
            .toList();

        searchResults.addAll(filtered);
        page++;
      } catch (e) {
        print('搜尋第 $page 頁時發生錯誤: $e');
        break;
      }
    }

    return searchResults;
  }
}

class AudioApiException implements Exception {
  final String message;
  final int statusCode;

  AudioApiException(this.message, this.statusCode);

  @override
  String toString() => 'AudioApiException: $message (Status: $statusCode)';
}
