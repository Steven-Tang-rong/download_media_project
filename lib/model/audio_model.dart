import '../utils/date_formatter.dart';

class AudioResponse {
  final int total;
  final List<AudioItem> data;

  AudioResponse({
    required this.total,
    required this.data,
  });

  factory AudioResponse.fromJson(Map<String, dynamic> json) {
    return AudioResponse(
      total: json['total'] ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => AudioItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

/// 音訊項目資料模型
class AudioItem {
  final int id;
  final String title;
  final String? summary;
  final String url;
  final String? fileExt;
  final String modified;

  AudioItem({
    required this.id,
    required this.title,
    this.summary,
    required this.url,
    this.fileExt,
    required this.modified,
  });

  factory AudioItem.fromJson(Map<String, dynamic> json) {
    return AudioItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      summary: json['summary'],
      url: json['url'] ?? '',
      fileExt: json['file_ext'],
      modified: json['modified'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'url': url,
      'file_ext': fileExt,
      'modified': modified,
    };
  }

  DateTime? get modifiedDateTime {
    try {
      return DateTime.parse(modified);
    } catch (e) {
      return null;
    }
  }

  String get formattedModifiedDate {
    final dateTime = modifiedDateTime;
    if (dateTime == null) return modified;
    return formatDate(dateTime);
  }

  bool get hasSummary => summary != null && summary!.isNotEmpty;

  bool get hasFileExt => fileExt != null && fileExt!.isNotEmpty;

  String get audioType {
    if (!hasFileExt) return '音訊';

    switch (fileExt!.toLowerCase()) {
      case '.mp3':
        return 'MP3';
      case '.wav':
        return 'WAV';
      case '.m4a':
        return 'M4A';
      case '.aac':
        return 'AAC';
      default:
        return '音訊';
    }
  }
}
