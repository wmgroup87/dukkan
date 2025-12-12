class Product {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String thumbnailUrl;
  final String publisherName;
  final String publisherId;
  final double price;
  final String mediaType;
  final String category;

  bool isLiked;
  bool isFollowed;
  int likesCount;
  int commentsCount;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.thumbnailUrl = '',
    required this.publisherName,
    required this.publisherId,
    required this.price,
    this.mediaType = 'image',
    this.category = '',
    this.isLiked = false,
    this.isFollowed = false,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    final dynamic priceValue = data['price'];
    final double price = priceValue is int
        ? priceValue.toDouble()
        : (priceValue as num?)?.toDouble() ?? 0.0;

    return Product(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      publisherName: data['publisherName'] as String? ?? '',
      publisherId: data['publisherId'] as String? ?? '',
      price: price,
      mediaType: data['mediaType'] as String? ?? 'image',
      category: data['category'] as String? ?? '',
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'publisherName': publisherName,
      'publisherId': publisherId,
      'price': price,
      'mediaType': mediaType,
      'category': category,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }
}
