class StockEntryModel {
  final int id;
  final int variantId;
  final String variantName;
  final int locationId;
  final String locationName;
  final String entryType;
  final double quantity;
  final String referenceNumber;
  final String? batchNumber;
  final String? expiryDate;
  final int? supplierId;
  final String note;
  final int? loggedById;
  final String? loggedByName;
  final bool isApproved;
  final String timestamp;

  StockEntryModel({
    required this.id,
    required this.variantId,
    required this.variantName,
    required this.locationId,
    required this.locationName,
    required this.entryType,
    required this.quantity,
    required this.referenceNumber,
    this.batchNumber,
    this.expiryDate,
    this.supplierId,
    required this.note,
    this.loggedById,
    this.loggedByName,
    required this.isApproved,
    required this.timestamp,
  });

  factory StockEntryModel.fromJson(Map<String, dynamic> json) => StockEntryModel(
    id: json['id'],
    variantId: json['variant'],
    variantName: json['variant_name'] ?? '',
    locationId: json['location'],
    locationName: json['location_name'] ?? '',
    entryType: json['entry_type'] ?? 'IN',
    quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0.0,
    referenceNumber: json['reference_number'] ?? '',
    batchNumber: json['batch_number'],
    expiryDate: json['expiry_date'],
    supplierId: json['supplier'],
    note: json['note'] ?? '',
    loggedById: json['logged_by'],
    loggedByName: json['logged_by_name'],
    isApproved: json['is_approved'] ?? false,
    timestamp: json['timestamp'] ?? '',
  );
}

class LocationModel {
  final int id;
  final String name;
  final String type;
  final String address;
  final bool isActive;

  LocationModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.isActive,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    id: json['id'],
    name: json['name'] ?? '',
    type: json['type'] ?? 'WAREHOUSE',
    address: json['address'] ?? '',
    isActive: json['is_active'] ?? true,
  );
}

class StockTransferModel {
  final int id;
  final int fromLocationId;
  final String fromLocationName;
  final int toLocationId;
  final String toLocationName;
  final int variantId;
  final String variantName;
  final double quantity;
  final String note;
  final String timestamp;

  StockTransferModel({
    required this.id,
    required this.fromLocationId,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationName,
    required this.variantId,
    required this.variantName,
    required this.quantity,
    required this.note,
    required this.timestamp,
  });

  factory StockTransferModel.fromJson(Map<String, dynamic> json) => StockTransferModel(
    id: json['id'],
    fromLocationId: json['from_location'],
    fromLocationName: json['from_location_name'] ?? '',
    toLocationId: json['to_location'],
    toLocationName: json['to_location_name'] ?? '',
    variantId: json['variant'],
    variantName: json['variant_name'] ?? '',
    quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0.0,
    note: json['note'] ?? '',
    timestamp: json['timestamp'] ?? '',
  );
}
