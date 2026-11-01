class Product {
  final int id;
  final String name;
  final String unit;
  final double price;
  final double stockQuantity;
  final String? imageUrl;
  final int categoryId;

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stockQuantity,
    this.imageUrl,
    required this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      unit: json['unit'],
      price: (json['price'] as num).toDouble(),
      stockQuantity:
          (json['stock_quantity'] as num).toDouble(),
      imageUrl: json['image_url'],
      categoryId: json['category_id'],
    );
  }
}