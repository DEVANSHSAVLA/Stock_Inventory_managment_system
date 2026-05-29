import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const _boxPendingEntries = 'pending_entries';
  static const _boxCachedStock = 'cached_stock';
  static const _boxCachedProducts = 'cached_products';
  static const _boxUserData = 'user_data';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_boxPendingEntries);
    await Hive.openBox<dynamic>(_boxCachedStock);
    await Hive.openBox<dynamic>(_boxCachedProducts);
    await Hive.openBox<dynamic>(_boxUserData);
  }

  static Box<Map> get pendingEntries => Hive.box<Map>(_boxPendingEntries);
  static Box<dynamic> get cachedStock => Hive.box<dynamic>(_boxCachedStock);
  static Box<dynamic> get cachedProducts => Hive.box<dynamic>(_boxCachedProducts);
  static Box<dynamic> get userData => Hive.box<dynamic>(_boxUserData);

  static Future<void> savePendingEntry(Map<String, dynamic> entry) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await pendingEntries.put(id, entry);
  }

  static List<MapEntry<dynamic, Map>> getAllPendingEntries() {
    return pendingEntries.toMap().entries.toList();
  }

  static Future<void> deletePendingEntry(dynamic key) async {
    await pendingEntries.delete(key);
  }

  static Future<void> cacheUserData(Map<String, dynamic> data) async {
    await userData.put('current_user', data);
  }

  static Map<String, dynamic>? getCachedUser() {
    final data = userData.get('current_user');
    if (data != null) return Map<String, dynamic>.from(data as Map);
    return null;
  }

  static Future<void> clearAll() async {
    await userData.clear();
    await cachedStock.clear();
    await cachedProducts.clear();
  }
}
