class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final double price; // Maps to normal_price for backwards compatibility with new UI
  final String unit;
  final String category;
  final String brand;
  final String weight;
  final int stock;
  final String? expiryDate;
  final String? imageUrl;
  final Promotion? promotion;

  // Fields from old project
  final num normalPrice;
  final num? promoPrice;
  final String? promoLabel;
  final bool memberOnly;
  final String? promoStart;
  final String? promoEnd;
  final int promoQty;
  final int promoTotal;
  final num? memberPrice;
  final bool pointX2;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.price,
    required this.unit,
    required this.category,
    required this.brand,
    required this.weight,
    required this.stock,
    this.expiryDate,
    this.imageUrl,
    this.promotion,
    
    required this.normalPrice,
    this.promoPrice,
    this.promoLabel,
    required this.memberOnly,
    this.promoStart,
    this.promoEnd,
    required this.promoQty,
    required this.promoTotal,
    this.memberPrice,
    required this.pointX2,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      barcode: json['barcode'] ?? '',
      price: (json['normal_price'] ?? json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'ชิ้น',
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      weight: json['weight'] ?? '',
      stock: json['stock'] ?? 99,
      expiryDate: json['expiry_date'],
      imageUrl: json['image_url'],
      promotion: json['promo_label'] != null
          ? Promotion(label: json['promo_label'], until: json['promo_end'])
          : (json['promotion'] != null ? Promotion.fromJson(json['promotion']) : null),
      
      // Old fields mapping
      normalPrice: json['normal_price'] ?? 0,
      promoPrice: json['promo_price'],
      promoLabel: json['promo_label'],
      memberOnly: json['member_only'] ?? false,
      promoStart: json['promo_start'],
      promoEnd: json['promo_end'],
      promoQty: json['promo_qty'] ?? 0,
      promoTotal: json['promo_total'] ?? 0,
      memberPrice: json['member_price'],
      pointX2: json['point_x2'] ?? false,
    );
  }
  
  num get basePriceForPromo => (promoPrice != null && promoPrice! > 0) ? promoPrice! : (normalPrice > 0 ? normalPrice : price);
  bool get isBuy1Get1 => promoQty == 2 && promoTotal > 0 && promoTotal == basePriceForPromo;
  bool get isBuy2Get1 => promoQty == 3 && promoTotal > 0 && promoTotal == (basePriceForPromo * 2);
}

class Promotion {
  final String label;
  final String? until;

  Promotion({required this.label, this.until});

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      label: json['label'] ?? '',
      until: json['until'],
    );
  }
}
