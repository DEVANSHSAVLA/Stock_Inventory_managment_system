class ProductModel {
  final int id;
  final String name;
  final String category;
  final String unitOfMeasure;
  final String description;
  final bool isActive;
  final List<VariantModel> variants;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unitOfMeasure,
    required this.description,
    required this.isActive,
    required this.variants,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'],
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    unitOfMeasure: json['unit_of_measure'] ?? 'units',
    description: json['description'] ?? '',
    isActive: json['is_active'] ?? true,
    variants: (json['variants'] as List<dynamic>? ?? [])
        .map((v) => VariantModel.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}

class VariantModel {
  final int id;
  final int productId;
  final String productName;
  final String size;
  final String flavour;
  final String sku;
  final String barcode;
  final int reorderPoint;
  final int reorderQty;
  final bool isActive;
  final double? erpPrice;
  final double? sellingPrice;
  final double? mrp;
  final double? weight;
  final double? length;
  final double? width;
  final double? height;
  final int caseQuantity;
  final double? caseWeight;
  final String? caseDimension;
  final String? driveImageUrl;
  double? liveStock;

  VariantModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.size,
    required this.flavour,
    required this.sku,
    required this.barcode,
    required this.reorderPoint,
    required this.reorderQty,
    required this.isActive,
    this.erpPrice,
    this.sellingPrice,
    this.mrp,
    this.weight,
    this.length,
    this.width,
    this.height,
    required this.caseQuantity,
    this.caseWeight,
    this.caseDimension,
    this.driveImageUrl,
    this.liveStock,
  });

  factory VariantModel.fromJson(Map<String, dynamic> json) => VariantModel(
    id: json['id'],
    productId: json['product'] ?? 0,
    productName: json['product_name'] ?? '',
    size: json['size'] ?? '',
    flavour: json['flavour'] ?? '',
    sku: json['sku'] ?? '',
    barcode: json['barcode'] ?? '',
    reorderPoint: json['reorder_point'] ?? 10,
    reorderQty: json['reorder_qty'] ?? 50,
    isActive: json['is_active'] ?? true,
    erpPrice: json['erp_price'] != null ? double.tryParse(json['erp_price'].toString()) : null,
    sellingPrice: json['selling_price'] != null ? double.tryParse(json['selling_price'].toString()) : null,
    mrp: json['mrp'] != null ? double.tryParse(json['mrp'].toString()) : null,
    weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
    length: json['length'] != null ? double.tryParse(json['length'].toString()) : null,
    width: json['width'] != null ? double.tryParse(json['width'].toString()) : null,
    height: json['height'] != null ? double.tryParse(json['height'].toString()) : null,
    caseQuantity: json['case_quantity'] ?? 144,
    caseWeight: json['case_weight'] != null ? double.tryParse(json['case_weight'].toString()) : null,
    caseDimension: json['case_dimension'],
    driveImageUrl: json['drive_image_url'],
    liveStock: json['live_stock'] != null ? double.tryParse(json['live_stock'].toString()) : null,
  );

  String get displayName => '$productName ${size.isNotEmpty ? size : ''} ${flavour.isNotEmpty ? flavour : ''}'.trim();
}
