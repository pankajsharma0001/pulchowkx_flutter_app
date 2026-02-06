/// Notice model for exam results and routines
class Notice {
  final int id;
  final String title;
  final String content;
  final NoticeSection section;
  final NoticeSubsection subsection;
  final String? attachmentUrl;
  final String? attachmentName;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoticeAuthor? author;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.section,
    required this.subsection,
    this.attachmentUrl,
    this.attachmentName,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      section: NoticeSection.fromString(
        json['section'] as String? ?? 'results',
      ),
      subsection: NoticeSubsection.fromString(
        json['subsection'] as String? ?? 'be',
      ),
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      authorId: json['authorId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      author: json['author'] != null
          ? NoticeAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'section': section.value,
      'subsection': subsection.value,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (author != null) 'author': author!.toJson(),
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

    // Check for PDF
    if (lowerUrl.endsWith('.pdf') || lowerName.endsWith('.pdf')) {
      return NoticeAttachmentType.pdf;
    }

    // Check for Google Drive links
    if (lowerUrl.contains('drive.google.com') ||
        lowerUrl.contains('docs.google.com')) {
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

    return NoticeAttachmentType.image; // Default to image
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Notice author information
class NoticeAuthor {
  final String id;
  final String name;
  final String? email;

  NoticeAuthor({required this.id, required this.name, this.email});

  factory NoticeAuthor.fromJson(Map<String, dynamic> json) {
    return NoticeAuthor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, if (email != null) 'email': email};
  }
}

/// Notice statistics
class NoticeStats {
  final int total;
  final int beResults;
  final int mscResults;
  final int beRoutines;
  final int mscRoutines;
  final int newCount;

  NoticeStats({
    required this.total,
    required this.beResults,
    required this.mscResults,
    required this.beRoutines,
    required this.mscRoutines,
    required this.newCount,
  });

  factory NoticeStats.fromJson(Map<String, dynamic> json) {
    return NoticeStats(
      total: _parseInt(json['total']) ?? 0,
      beResults: _parseInt(json['beResults']) ?? 0,
      mscResults: _parseInt(json['mscResults']) ?? 0,
      beRoutines: _parseInt(json['beRoutines']) ?? 0,
      mscRoutines: _parseInt(json['mscRoutines']) ?? 0,
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

/// Notice subsection/program type
enum NoticeSubsection {
  be('be'),
  msc('msc');

  final String value;
  const NoticeSubsection(this.value);

  static NoticeSubsection fromString(String value) {
    return NoticeSubsection.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NoticeSubsection.be,
    );
  }
}

/// Notice attachment type
enum NoticeAttachmentType { none, image, pdf }

/// Notice filters for API calls
class NoticeFilters {
  final NoticeSection? section;
  final NoticeSubsection? subsection;
  final String? search;
  final int? limit;
  final int? offset;

  NoticeFilters({
    this.section,
    this.subsection,
    this.search,
    this.limit,
    this.offset,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (section != null) params['section'] = section!.value;
    if (subsection != null) params['subsection'] = subsection!.value;
    if (search != null && search!.isNotEmpty) params['search'] = search!;
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();
    return params;
  }
}
