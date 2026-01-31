import 'package:pulchowkx_app/models/book_listing.dart';

class MarketplaceMessage {
  final int id;
  final int conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final BookSeller? sender; // Reusing BookSeller for user info if available

  MarketplaceMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.sender,
  });

  factory MarketplaceMessage.fromJson(Map<String, dynamic> json) {
    return MarketplaceMessage(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      content: json['content'],
      isRead: json['isRead'] == "true" || json['isRead'] == true,
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      sender: json['sender'] != null
          ? BookSeller.fromJson(json['sender'])
          : null,
    );
  }
}

class MarketplaceConversation {
  final int id;
  final int listingId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookListing? listing;
  final BookSeller? buyer;
  final BookSeller? seller;
  final List<MarketplaceMessage>? messages;

  MarketplaceConversation({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
    this.buyer,
    this.seller,
    this.messages,
  });

  factory MarketplaceConversation.fromJson(Map<String, dynamic> json) {
    return MarketplaceConversation(
      id: json['id'],
      listingId: json['listingId'],
      buyerId: json['buyerId'],
      sellerId: json['sellerId'],
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt']).toLocal(),
      listing: json['listing'] != null
          ? BookListing.fromJson(json['listing'])
          : null,
      buyer: json['buyer'] != null ? BookSeller.fromJson(json['buyer']) : null,
      seller: json['seller'] != null
          ? BookSeller.fromJson(json['seller'])
          : null,
      messages: json['messages'] != null
          ? (json['messages'] as List)
                .map((m) => MarketplaceMessage.fromJson(m))
                .toList()
          : null,
    );
  }

  MarketplaceMessage? get lastMessage =>
      (messages != null && messages!.isNotEmpty) ? messages!.first : null;
}
