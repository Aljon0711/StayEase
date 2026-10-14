class Room {
  final String name;
  final String? category;
  final String floor;
  final String size;
  final String price;
  final String priceUnit;
  final String status;
  final String imageUrl;
  final String? details;

  Room({
    required this.name,
    this.category,
    required this.floor,
    required this.size,
    required this.price,
    required this.priceUnit,
    required this.status,
    required this.imageUrl,
    this.details,
  });
}
