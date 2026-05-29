class SupplierModel {
  final int id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final bool isActive;

  SupplierModel({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    required this.isActive,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: json['id'],
    name: json['name'] ?? '',
    contactPerson: json['contact_person'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'] ?? '',
    address: json['address'] ?? '',
    isActive: json['is_active'] ?? true,
  );
}

class PurchaseOrderModel {
  final int id;
  final int supplierId;
  final String supplierName;
  final String status;
  final List<dynamic> items;
  final String? expectedDate;
  final String notes;
  final String createdAt;

  PurchaseOrderModel({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.items,
    this.expectedDate,
    required this.notes,
    required this.createdAt,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) => PurchaseOrderModel(
    id: json['id'],
    supplierId: json['supplier'],
    supplierName: json['supplier_name'] ?? '',
    status: json['status'] ?? 'DRAFT',
    items: json['items'] as List<dynamic>? ?? [],
    expectedDate: json['expected_date'],
    notes: json['notes'] ?? '',
    createdAt: json['created_at'] ?? '',
  );
}

class NotificationModel {
  final int id;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'],
    message: json['message'] ?? '',
    type: json['type'] ?? 'SYSTEM',
    isRead: json['is_read'] ?? false,
    createdAt: json['created_at'] ?? '',
  );
}
