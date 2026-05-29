import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../auth/providers/auth_provider.dart';

final ordersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(ApiUrls.orders);
  return res.data['data']['results'] as List<dynamic>;
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrders = ref.watch(ordersProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: const AppBarWidget(title: 'Orders & Deliveries'),
      drawer: const AppDrawer(),
      body: asyncOrders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          return _buildKanbanBoard(orders, user, ref);
        },
      ),
      floatingActionButton: user?.canCreateOrders == true
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await context.push('/orders/new');
                if (result == true) {
                  ref.refresh(ordersProvider.future);
                }
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text('New Order', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildKanbanBoard(List<dynamic> allOrders, dynamic user, WidgetRef ref) {
    // Empty-state: guide first-time users
    if (allOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text('No orders yet', style: AppTextStyles.headingMedium.copyWith(color: AppColors.neutral600)),
            const SizedBox(height: 8),
            Text(
              'Create your first order to start tracking deliveries',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (user?.canCreateOrders == true)
              ElevatedButton.icon(
                onPressed: () => GoRouter.of(ref.context).push('/orders/new'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Create Your First Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      );
    }

    final columns = [
      {'title': 'PENDING', 'status': 'PENDING', 'color': AppColors.warning},
      {'title': 'CONFIRMED', 'status': 'CONFIRMED', 'color': AppColors.primary},
      {'title': 'DISPATCHED', 'status': 'DISPATCHED', 'color': AppColors.secondary},
      {'title': 'DELIVERED', 'status': 'DELIVERED', 'color': AppColors.success},
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(ordersProvider.future),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.map((col) {
            final colOrders = allOrders.where((o) => o['status'] == col['status']).toList();
            return Container(
              width: 320,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (col['color'] as Color).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(col['title'] as String, style: AppTextStyles.headingSmall.copyWith(color: col['color'] as Color)),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: col['color'] as Color,
                          child: Text('${colOrders.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: colOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _OrderCard(
                        order: colOrders[i], 
                        onRefresh: () => ref.refresh(ordersProvider.future), 
                        user: user
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRefresh;
  final dynamic user;

  const _OrderCard({required this.order, required this.onRefresh, required this.user});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return AppColors.warning;
      case 'CONFIRMED': return AppColors.primary;
      case 'DISPATCHED': return AppColors.secondary;
      case 'DELIVERED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default: return AppColors.neutral500;
    }
  }

  Future<void> _updateStatus(WidgetRef ref, BuildContext context, String action) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiUrls.orders + '${order['id']}/$action/');
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order marked as $action'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order['status'] ?? 'UNKNOWN';
    final items = order['items'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['order_number'] ?? '', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 4),
                    Text(order['customer_name'] ?? '', style: AppTextStyles.bodyMedium),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${item['variant_name']} x ${item['quantity']}', style: AppTextStyles.bodySmall)),
                          Text(item['location_name'] ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral400)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          if (status == 'PENDING' || status == 'CONFIRMED' || status == 'DISPATCHED') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  if (status == 'PENDING' && user?.canApprove == true)
                    TextButton(onPressed: () => _updateStatus(ref, context, 'confirm'), child: const Text('Confirm')),
                  if (status == 'PENDING' && user?.canApprove == true)
                    TextButton(onPressed: () => _updateStatus(ref, context, 'cancel'), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Cancel')),
                  if (status == 'CONFIRMED' && user?.canDispatchOrders == true)
                    TextButton(onPressed: () => _updateStatus(ref, context, 'dispatch'), child: const Text('Dispatch')),
                  if (status == 'DISPATCHED' && user?.canDispatchOrders == true)
                    TextButton(onPressed: () => _updateStatus(ref, context, 'deliver'), child: const Text('Mark Delivered')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
