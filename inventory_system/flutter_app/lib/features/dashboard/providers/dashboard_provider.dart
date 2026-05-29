import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/storage/secure_storage.dart';

class DashboardData {
  final int totalProducts;
  final int lowStockCount;
  final double todayInQty;
  final double todayOutQty;
  final List<dynamic> top5Movers;
  final List<dynamic> recent10Entries;
  final List<dynamic> balanceStock;
  final Map<String, dynamic> pendingForDelivery;

  const DashboardData({
    this.totalProducts = 0,
    this.lowStockCount = 0,
    this.todayInQty = 0,
    this.todayOutQty = 0,
    this.top5Movers = const [],
    this.recent10Entries = const [],
    this.balanceStock = const [],
    this.pendingForDelivery = const {'count': 0, 'orders': []},
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    totalProducts: int.tryParse(json['total_products']?.toString() ?? '') ?? 0,
    lowStockCount: int.tryParse(json['low_stock_count']?.toString() ?? '') ?? 0,
    todayInQty: double.tryParse(json['today_in_qty']?.toString() ?? '') ?? 0.0,
    todayOutQty: double.tryParse(json['today_out_qty']?.toString() ?? '') ?? 0.0,
    top5Movers: json['top_5_movers'] as List<dynamic>? ?? [],
    recent10Entries: json['recent_10_entries'] as List<dynamic>? ?? [],
    balanceStock: json['balance_stock'] as List<dynamic>? ?? [],
    pendingForDelivery: json['pending_for_delivery'] as Map<String, dynamic>? ?? {'count': 0, 'orders': []},
  );
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    // Safety guard: don't fire API calls if there is no auth token.
    final token = await SecureStorage().getAccessToken();
    if (token == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final response = await DioClient().dio.get(ApiUrls.dashboardSummary);
      state = AsyncValue.data(DashboardData.fromJson(response.data['data'] as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, AsyncValue<DashboardData>>(
  (ref) => DashboardNotifier(),
);
