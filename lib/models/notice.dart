import 'package:pulchowkx_app/services/api_service.dart';

/// Notice model for exam results and routines
class Notice {
  final int id;
  final String title;
  final String content;
  final NoticeSection section;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.section,
    this.attachmentUrl,
    this.attachmentName,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      section: NoticeSection.fromString(
        json['section'] as String? ?? 'results',
      ),
      attachmentUrl: ApiService.processImageUrl(
        json['attachmentUrl'] as String?,
      ),
      attachmentName: json['attachmentName'] as String?,
      category: json['category'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'section': section.value,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Check if notice was published within the last 7 days
  bool get isNew {
    final difference = DateTime.now().difference(createdAt);
    return difference.inDays < 7;
  }

  /// Get attachment type based on URL and name
  NoticeAttachmentType get attachmentType {
    if (attachmentUrl == null) return NoticeAttachmentType.none;

    final lowerUrl = attachmentUrl!.toLowerCase();
    final lowerName = (attachmentName ?? '').toLowerCase();

    // Check for PDF (including Drive/Docs links)
    if (lowerUrl.endsWith('.pdf') ||
        lowerName.endsWith('.pdf') ||
        lowerUrl.contains('drive.google.com') ||
        lowerUrl.contains('docs.google.com') ||
        lowerUrl.contains('dropbox.com')) {
      return NoticeAttachmentType.pdf;
    }

    // Check for known image extensions
    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.svg',
      '.bmp',
    ];
    for (final ext in imageExtensions) {
      if (lowerUrl.endsWith(ext) || lowerName.endsWith(ext)) {
        return NoticeAttachmentType.image;
      }
    }

    // If it's just a generic URL without extension, it's safer to open externally
    if (!lowerUrl.contains('.') || lowerUrl.split('/').last.contains('?')) {
      return NoticeAttachmentType.none;
    }

    return NoticeAttachmentType
        .image; // Final fallback for anything else with an extension
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// NoticeAuthor is kept for backward compatibility if needed, but removed from Notice model as per schema update

/// Notice statistics
class NoticeStats {
  final int total;
  final int results;
  final int applicationForms;
  final int examCenters;
  final int general;
  final int newCount;

  NoticeStats({
    required this.total,
    required this.results,
    required this.applicationForms,
    required this.examCenters,
    required this.general,
    required this.newCount,
  });

  factory NoticeStats.fromJson(Map<String, dynamic> json) {
    return NoticeStats(
      total: _parseInt(json['total']) ?? 0,
      results: _parseInt(json['results']) ?? 0,
      applicationForms: _parseInt(json['applicationForms']) ?? 0,
      examCenters: _parseInt(json['examCenters']) ?? 0,
      general: _parseInt(json['general']) ?? 0,
      newCount: _parseInt(json['newCount']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Notice section type
enum NoticeSection {
  results('results'),
  routines('routines');

  final String value;
  const NoticeSection(this.value);

  static NoticeSection fromString(String value) {
    return NoticeSection.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NoticeSection.results,
    );
  }
}

/// Notice attachment type
enum NoticeAttachmentType { none, image, pdf }

/// Notice filters for API calls
class NoticeFilters {
  final NoticeSection? section;
  final String? category;
  final String? search;
  final int? limit;
  final int? offset;

  NoticeFilters({
    this.section,
    this.category,
    this.search,
    this.limit,
    this.offset,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (section != null) params['section'] = section!.value;
    if (category != null) params['category'] = category!;
    if (search != null && search!.isNotEmpty) params['search'] = search!;
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    return params;
  }
}
