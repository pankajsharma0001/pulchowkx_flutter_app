import 'package:intl/intl.dart';
import 'package:pulchowkx_app/services/api_service.dart';

enum LostFoundItemType { lost, found }

enum LostFoundCategory {
  documents,
  electronics,
  accessories,
  idsCards,
  keys,
  bags,
  other,
}

enum LostFoundStatus {
  open,
  claimed,
  resolved,
  closed;

  String get displayName {
    switch (this) {
      case LostFoundStatus.open:
        return 'Open';
      case LostFoundStatus.claimed:
        return 'Claimed';
      case LostFoundStatus.resolved:
        return 'Resolved';
      case LostFoundStatus.closed:
        return 'Closed';
    }
  }
}

enum LostFoundClaimStatus { pending, accepted, rejected, cancelled }

class LostFoundItem {
  final int id;
  final String ownerId;
  final LostFoundItemType itemType;
  final String title;
  final String description;
  final LostFoundCategory category;
  final DateTime lostFoundDate;
  final String locationText;
  final String? contactNote;
  final LostFoundStatus status;
  final String? rewardText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LostFoundImage> images;
  final List<LostFoundClaim>? claims;
  final Map<String, dynamic>? owner;

  LostFoundItem({
    required this.id,
    required this.ownerId,
    required this.itemType,
    required this.title,
    required this.description,
    required this.category,
    required this.lostFoundDate,
    required this.locationText,
    this.contactNote,
    required this.status,
    this.rewardText,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.claims,
    this.owner,
  });

  factory LostFoundItem.fromJson(Map<String, dynamic> json) {
    return LostFoundItem(
      id: json['id'] as int,
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String? ?? '',
      itemType: _parseItemType(json['itemType'] ?? json['item_type']),
      title: json['title'] as String,
      description: json['description'] as String,
      category: _parseCategory(json['category'] ?? 'other'),
      lostFoundDate:
          json['lostFoundDate'] != null || json['lost_found_date'] != null
          ? DateTime.parse(json['lostFoundDate'] ?? json['lost_found_date'])
          : DateTime.now(),
      locationText:
          (json['locationText'] ?? json['location_text'] ?? '') as String,
      contactNote: json['contactNote'] ?? json['contact_note'] as String?,
      status: _parseStatus(json['status']),
      rewardText: json['rewardText'] ?? json['reward_text'] as String?,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(
        json['updatedAt'] ??
            json['updated_at'] ??
            (json['createdAt'] ?? json['created_at']),
      ),
      images:
          (json['images'] as List<dynamic>?)
              ?.map((i) => LostFoundImage.fromJson(i as Map<String, dynamic>))
              .where((i) => i.imageUrl.isNotEmpty)
              .toList() ??
          [],
      claims: (json['claims'] as List<dynamic>?)
          ?.map((c) => LostFoundClaim.fromJson(c as Map<String, dynamic>))
          .toList(),
      owner: json['owner'] as Map<String, dynamic>?,
    );
  }

  factory LostFoundItem.fromPartialJson(Map<String, dynamic> json) {
    return LostFoundItem(
      id: json['id'] as int,
      ownerId: '',
      itemType: _parseItemType(json['itemType'] ?? json['item_type']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: LostFoundCategory.other,
      lostFoundDate: DateTime.now(),
      locationText:
          (json['locationText'] ?? json['location_text'] ?? '') as String,
      status: _parseStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: DateTime.now(),
      images: json['imageUrl'] != null
          ? [
              LostFoundImage(
                id: 0,
                itemId: json['id'] as int,
                imageUrl:
                    ApiService.processImageUrl(json['imageUrl'] as String?) ??
                    '',
              ),
            ].where((i) => i.imageUrl.isNotEmpty).toList()
          : [],
    );
  }

  static LostFoundItemType _parseItemType(dynamic value) {
    if (value == 'lost') return LostFoundItemType.lost;
    return LostFoundItemType.found;
  }

  static LostFoundCategory _parseCategory(dynamic value) {
    switch (value) {
      case 'documents':
        return LostFoundCategory.documents;
      case 'electronics':
        return LostFoundCategory.electronics;
      case 'accessories':
        return LostFoundCategory.accessories;
      case 'ids_cards':
      case 'idsCards':
        return LostFoundCategory.idsCards;
      case 'keys':
        return LostFoundCategory.keys;
      case 'bags':
        return LostFoundCategory.bags;
      default:
        return LostFoundCategory.other;
    }
  }

  static LostFoundStatus _parseStatus(dynamic value) {
    switch (value) {
      case 'open':
        return LostFoundStatus.open;
      case 'claimed':
        return LostFoundStatus.claimed;
      case 'resolved':
        return LostFoundStatus.resolved;
      case 'closed':
        return LostFoundStatus.closed;
      default:
        return LostFoundStatus.open;
    }
  }

  String get dateFormatted => DateFormat('MMM dd, yyyy').format(lostFoundDate);
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class LostFoundImage {
  final int id;
  final int itemId;
  final String imageUrl;
  final int sortOrder;

  LostFoundImage({
    required this.id,
    required this.itemId,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  factory LostFoundImage.fromJson(Map<String, dynamic> json) {
    return LostFoundImage(
      id: json['id'] as int,
      itemId: json['itemId'] ?? json['item_id'] as int,
      imageUrl:
          ApiService.processImageUrl(
            json['imageUrl'] ?? json['image_url'] as String?,
          ) ??
          '',
      sortOrder: json['sortOrder'] ?? json['sort_order'] as int? ?? 0,
    );
  }
}

class LostFoundClaim {
  final int id;
  final int itemId;
  final String requesterId;
  final String message;
  final LostFoundClaimStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? requester;
  final LostFoundItem? item;

  LostFoundClaim({
    required this.id,
    required this.itemId,
    required this.requesterId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.requester,
    this.item,
  });

  factory LostFoundClaim.fromJson(Map<String, dynamic> json) {
    return LostFoundClaim(
      id: json['id'] as int,
      itemId: json['itemId'] ?? json['item_id'] as int,
      requesterId: json['requesterId'] ?? json['requester_id'] as String,
      message: json['message'] as String,
      status: _parseClaimStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      requester: json['requester'] as Map<String, dynamic>?,
      item: json['item'] != null
          ? LostFoundItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
    );
  }

  static LostFoundClaimStatus _parseClaimStatus(dynamic value) {
    switch (value) {
      case 'pending':
        return LostFoundClaimStatus.pending;
      case 'accepted':
        return LostFoundClaimStatus.accepted;
      case 'rejected':
        return LostFoundClaimStatus.rejected;
      case 'cancelled':
        return LostFoundClaimStatus.cancelled;
      default:
        return LostFoundClaimStatus.pending;
    }
  }
}
