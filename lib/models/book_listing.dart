/// Book condition enum matching backend enum
enum BookCondition {
  newBook('new', 'New'),
  likeNew('like_new', 'Like New'),
  good('good', 'Good'),
  fair('fair', 'Fair'),
  poor('poor', 'Poor');

  const BookCondition(this.value, this.label);
  final String value;
  final String label;

  static BookCondition fromString(String? value) {
    return BookCondition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookCondition.good,
    );
  }
}

/// Book listing status enum
enum BookStatus {
  available('available', 'Available'),
  pending('pending', 'Pending'),
  sold('sold', 'Sold'),
  removed('removed', 'Removed');

  const BookStatus(this.value, this.label);
  final String value;
  final String label;

  static BookStatus fromString(String? value) {
    return BookStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookStatus.available,
    );
  }
}

/// Book image model
class BookImage {
  final int id;
  final int listingId;
  final String imageUrl;
  final String? imagePublicId;
  final DateTime createdAt;

  BookImage({
    required this.id,
    required this.listingId,
    required this.imageUrl,
    this.imagePublicId,
    required this.createdAt,
  });

  factory BookImage.fromJson(Map<String, dynamic> json) {
    return BookImage(
      id: json['id'] as int? ?? 0,
      listingId: json['listingId'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      imagePublicId: json['imagePublicId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'listingId': listingId,
    'imageUrl': imageUrl,
    'imagePublicId': imagePublicId,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Book category model
class BookCategory {
  final int id;
  final String name;
  final String? description;
  final int? parentCategoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookCategory? parentCategory;
  final List<BookCategory>? subcategories;

  BookCategory({
    required this.id,
    required this.name,
    this.description,
    this.parentCategoryId,
    required this.createdAt,
    required this.updatedAt,
    this.parentCategory,
    this.subcategories,
  });

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    return BookCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentCategoryId: json['parentCategoryId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      parentCategory: json['parentCategory'] != null
          ? BookCategory.fromJson(
              json['parentCategory'] as Map<String, dynamic>,
            )
          : null,
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
                .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'parentCategoryId': parentCategoryId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Book seller info
class BookSeller {
  final String id;
  final String name;
  final String? email;
  final String? image;

  BookSeller({required this.id, required this.name, this.email, this.image});

  factory BookSeller.fromJson(Map<String, dynamic> json) {
    return BookSeller(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      image: json['image'] as String?,
    );
  }
}

/// Main book listing model
class BookListing {
  final int id;
  final String sellerId;
  final String title;
  final String author;
  final String? isbn;
  final String? edition;
  final String? publisher;
  final int? publicationYear;
  final BookCondition condition;
  final String? description;
  final String price;
  final BookStatus status;
  final String? courseCode;
  final int? categoryId;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? soldAt;
  final BookSeller? seller;
  final List<BookImage>? images;
  final BookCategory? category;
  final bool isSaved;
  final bool isOwner;
  final String? buyerContactInfo;
  final int requestCount;

  BookListing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.author,
    this.isbn,
    this.edition,
    this.publisher,
    this.publicationYear,
    required this.condition,
    this.description,
    required this.price,
    required this.status,
    this.courseCode,
    this.categoryId,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
    this.soldAt,
    this.seller,
    this.images,
    this.category,
    this.isSaved = false,
    this.isOwner = false,
    this.buyerContactInfo,
    this.requestCount = 0,
  });

  factory BookListing.fromJson(Map<String, dynamic> json) {
    return BookListing(
      id: json['id'] as int,
      sellerId: json['sellerId'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      isbn: json['isbn'] as String?,
      edition: json['edition'] as String?,
      publisher: json['publisher'] as String?,
      publicationYear: json['publicationYear'] as int?,
      condition: BookCondition.fromString(json['condition'] as String?),
      description: json['description'] as String?,
      price: json['price'] as String,
      status: BookStatus.fromString(json['status'] as String?),
      courseCode: json['courseCode'] as String?,
      categoryId: json['categoryId'] as int?,
      viewCount: json['viewCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      soldAt: json['soldAt'] != null
          ? DateTime.parse(json['soldAt'] as String)
          : null,
      seller: json['seller'] != null
          ? BookSeller.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => BookImage.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      category: json['category'] != null
          ? BookCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isSaved: json['isSaved'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      buyerContactInfo: json['buyerContactInfo'] as String?,
      requestCount: json['requestCount'] as int? ?? 0,
    );
  }

  /// Parse partial book data from search endpoint
  /// The search endpoint returns only: id, title, author, price, status, sellerId
  factory BookListing.fromPartialJson(Map<String, dynamic> json) {
    return BookListing(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      sellerId: json['sellerId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      author: json['author']?.toString() ?? 'Unknown Author',
      isbn: json['isbn']?.toString(),
      edition: json['edition']?.toString(),
      publisher: json['publisher']?.toString(),
      publicationYear: json['publicationYear'] is int
          ? json['publicationYear'] as int
          : int.tryParse(json['publicationYear']?.toString() ?? ''),
      condition: BookCondition.fromString(json['condition']?.toString()),
      description: json['description']?.toString(),
      price: json['price']?.toString() ?? '0',
      status: BookStatus.fromString(json['status']?.toString()),
      courseCode: json['courseCode']?.toString(),
      categoryId: json['categoryId'] is int
          ? json['categoryId'] as int
          : int.tryParse(json['categoryId']?.toString() ?? ''),
      viewCount: json['viewCount'] is int
          ? json['viewCount'] as int
          : int.tryParse(json['viewCount']?.toString() ?? '') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      soldAt: json['soldAt'] != null
          ? DateTime.tryParse(json['soldAt'].toString())
          : null,
      seller: json['seller'] != null
          ? BookSeller.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => BookImage.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      category: json['category'] != null
          ? BookCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isSaved: json['isSaved'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      buyerContactInfo: json['buyerContactInfo']?.toString(),
      requestCount: json['requestCount'] is int
          ? json['requestCount'] as int
          : int.tryParse(json['requestCount']?.toString() ?? '') ?? 0,
    );
  }

  /// Get the first image URL or null
  String? get primaryImageUrl =>
      images != null && images!.isNotEmpty ? images!.first.imageUrl : null;

  /// Get formatted price with currency
  String get formattedPrice => 'Rs. ${double.parse(price).toStringAsFixed(0)}';

  /// Check if book is available for purchase
  bool get isAvailable => status == BookStatus.available;
}

/// Saved book model
class SavedBook {
  final int id;
  final String userId;
  final int listingId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookListing? listing;

  SavedBook({
    required this.id,
    required this.userId,
    required this.listingId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
  });

  factory SavedBook.fromJson(Map<String, dynamic> json) {
    return SavedBook(
      id: json['id'] as int,
      userId: json['userId'] as String,
      listingId: json['listingId'] as int,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      listing: json['listing'] != null
          ? BookListing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Book purchase request status enum
enum RequestStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.value, this.label);
  final String value;
  final String label;

  static RequestStatus fromString(String? value) {
    return RequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RequestStatus.pending,
    );
  }
}

/// Book purchase request model
class BookPurchaseRequest {
  final int id;
  final int listingId;
  final String buyerId;
  final RequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final BookListing? listing;
  final BookSeller? buyer;

  BookPurchaseRequest({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.status,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
    this.buyer,
  });

  factory BookPurchaseRequest.fromJson(Map<String, dynamic> json) {
    return BookPurchaseRequest(
      id: json['id'] as int,
      listingId: json['listingId'] as int,
      buyerId: json['buyerId'] as String,
      status: RequestStatus.fromString(json['status'] as String?),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.parse(json['createdAt'] as String),
      listing: json['listing'] != null
          ? BookListing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
      buyer: json['buyer'] != null
          ? BookSeller.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Book filters for search/filter API
class BookFilters {
  final String? search;
  final String? author;
  final String? isbn;
  final int? categoryId;
  final String? condition;
  final double? minPrice;
  final double? maxPrice;
  final String? status;
  final String? sortBy; // 'price_asc', 'price_desc', 'newest', 'oldest'
  final int page;
  final int limit;

  BookFilters({
    this.search,
    this.author,
    this.isbn,
    this.categoryId,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.status,
    this.sortBy,
    this.page = 1,
    this.limit = 12,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (search != null && search!.isNotEmpty) params['search'] = search!;
    if (author != null && author!.isNotEmpty) params['author'] = author!;
    if (isbn != null && isbn!.isNotEmpty) params['isbn'] = isbn!;
    if (categoryId != null) params['categoryId'] = categoryId.toString();
    if (condition != null && condition!.isNotEmpty) {
      params['condition'] = condition!;
    }
    if (minPrice != null) params['minPrice'] = minPrice.toString();
    if (maxPrice != null) params['maxPrice'] = maxPrice.toString();
    if (status != null && status!.isNotEmpty) params['status'] = status!;
    if (sortBy != null && sortBy!.isNotEmpty) params['sortBy'] = sortBy!;
    params['page'] = page.toString();
    params['limit'] = limit.toString();
    return params;
  }

  BookFilters copyWith({
    String? search,
    String? author,
    String? isbn,
    int? categoryId,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? status,
    String? sortBy,
    int? page,
    int? limit,
  }) {
    return BookFilters(
      search: search ?? this.search,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      categoryId: categoryId ?? this.categoryId,
      condition: condition ?? this.condition,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      status: status ?? this.status,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

/// Pagination info model
class BookPagination {
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  BookPagination({
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  factory BookPagination.fromJson(Map<String, dynamic> json) {
    return BookPagination(
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalCount: json['totalCount'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

/// Book listings response model
class BookListingsResponse {
  final List<BookListing> listings;
  final BookPagination pagination;

  BookListingsResponse({required this.listings, required this.pagination});

  factory BookListingsResponse.fromJson(Map<String, dynamic> json) {
    return BookListingsResponse(
      listings: (json['listings'] as List)
          .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: BookPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );
  }
}
