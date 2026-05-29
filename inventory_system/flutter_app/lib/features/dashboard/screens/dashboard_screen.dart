import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/offline/sync_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _pollingTimer;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _connectWs() {
    final ws = ref.read(webSocketServiceProvider);
    ws.connect();
    
    // Listen to messages
    _messageSubscription = ws.messageStream.listen((payload) {
      if (payload['type'] == 'stock_update') {
        ref.read(dashboardProvider.notifier).fetch();
      }
    });

    // Listen to status for polling fallback
    _statusSubscription = ws.statusStream.listen((status) {
      if (status == WsStatus.connected) {
        _pollingTimer?.cancel();
        _pollingTimer = null;
      } else if (status == WsStatus.disconnected && _pollingTimer == null) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          ref.read(dashboardProvider.notifier).fetch();
        });
      }
    });
  }

  Widget build(BuildContext context) {
    ref.watch(autoSyncProvider); // Initialize auto-sync listener when user is authenticated
    final dashState = ref.watch(dashboardProvider);
    final wsService = ref.watch(webSocketServiceProvider);
    final authState = ref.watch(authProvider);
    final isViewer = authState.user?.role == 'VIEWER';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarWidget(
        title: 'Dashboard',
        isLive: wsService.status == WsStatus.connected,
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).fetch(),
              child: dashState.when(
                data: (data) => _buildContent(data, isViewer: isViewer),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DashboardData data, {bool isViewer = false}) {
    if (isViewer) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBalanceStock(data),
          const SizedBox(height: 20),
          _buildPendingForDelivery(data),
          const SizedBox(height: 24),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuickActions(),
        const SizedBox(height: 20),
        _buildKpiGrid(data),
        const SizedBox(height: 20),
        _buildChart(data),
        const SizedBox(height: 20),
        _buildBalanceStock(data),
        const SizedBox(height: 20),
        _buildPendingForDelivery(data),
        const SizedBox(height: 20),
        _buildLowStockSection(data),
        const SizedBox(height: 20),
        _buildRecentActivity(data),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(icon: Icons.add_shopping_cart, label: 'New Order', onTap: () => context.push('/orders/new')),
          const SizedBox(width: 12),
          _QuickActionButton(icon: Icons.arrow_downward, label: 'Add Stock', onTap: () => context.push('/stock/in')),
          const SizedBox(width: 12),
          _QuickActionButton(icon: Icons.local_shipping_outlined, label: 'Dispatch', onTap: () => context.push('/orders')),
          const SizedBox(width: 12),
          _QuickActionButton(icon: Icons.inventory, label: 'Products', onTap: () => context.push('/products')),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(DashboardData data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        KpiCard(
          title: 'Total Products',
          value: NumberFormatter.format(data.totalProducts),
          icon: Icons.inventory_2_outlined,
          color: AppColors.secondary,
        ),
        KpiCard(
          title: 'Low Stock Items',
          value: NumberFormatter.format(data.lowStockCount),
          icon: Icons.warning_amber_outlined,
          color: data.lowStockCount > 0 ? AppColors.error : AppColors.success,
        ),
        KpiCard(
          title: 'Today IN',
          value: NumberFormatter.formatQty(data.todayInQty),
          icon: Icons.arrow_downward_rounded,
          color: AppColors.success,
        ),
        KpiCard(
          title: 'Today OUT',
          value: NumberFormatter.formatQty(data.todayOutQty),
          icon: Icons.arrow_upward_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildChart(DashboardData data) {
    final inVal = data.todayInQty;
    final outVal = data.todayOutQty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s Movement', style: AppTextStyles.headingMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (inVal > outVal ? inVal : outVal) * 1.2 + 1,
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(toY: inVal, color: AppColors.success, width: 40, borderRadius: BorderRadius.circular(6)),
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(toY: outVal, color: AppColors.warning, width: 40, borderRadius: BorderRadius.circular(6)),
                ]),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                  return Text(v == 0 ? 'IN' : 'OUT', style: AppTextStyles.labelSmall);
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: false),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Low Stock Alerts', style: AppTextStyles.headingMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (data.lowStockCount == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                    const SizedBox(height: 8),
                    Text('All stock levels are healthy', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            )
          else
            ...data.top5Movers.take(5).map((m) => _buildLowStockItem(m as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildLowStockItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stockLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['variant__product__name']?.toString() ?? '', style: AppTextStyles.headingSmall),
                Text('SKU: ${item['variant__sku'] ?? ''}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item['total_qty'] ?? 0}',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          if (data.recent10Entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No recent activity', style: AppTextStyles.bodySmall),
              ),
            )
          else
            ...data.recent10Entries.map((e) => _buildActivityItem(e as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> entry) {
    final isIn = entry['entry_type'] == 'IN';
    final dt = DateFormatter.parseApi(entry['timestamp'] as String?);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isIn ? AppColors.successLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 16,
              color: isIn ? AppColors.successDark : AppColors.warningDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['variant_name']?.toString() ?? 'Unknown', style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${entry['logged_by_name'] ?? ''} • ${DateFormatter.timeAgo(dt)}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'}${NumberFormatter.formatQty(entry['quantity'])}',
            style: AppTextStyles.headingSmall.copyWith(
              color: isIn ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStock(DashboardData data) {
    if (data.balanceStock.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Balance Stock', style: AppTextStyles.headingMedium),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Size')),
                DataColumn(label: Text('Flavour')),
                DataColumn(label: Text('Cases'), numeric: true),
                DataColumn(label: Text('Pcs'), numeric: true),
              ],
              rows: data.balanceStock.take(20).map((item) {
                final cases = double.tryParse(item['live_stock_cases']?.toString() ?? '')?.toStringAsFixed(0) ?? '0';
                final pcs = double.tryParse(item['live_stock_pcs']?.toString() ?? '')?.toStringAsFixed(0) ?? '0';
                return DataRow(cells: [
                  DataCell(Text(item['product_name'] ?? '', style: AppTextStyles.labelLarge)),
                  DataCell(Text(item['size'] ?? '')),
                  DataCell(Text(item['flavour'] ?? '')),
                  DataCell(Text(cases)),
                  DataCell(Text(pcs)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingForDelivery(DashboardData data) {
    final pendingData = data.pendingForDelivery;
    final count = pendingData['count'] ?? 0;
    final orders = (pendingData['orders'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Pending for Delivery', style: AppTextStyles.headingMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: count > 0 ? AppColors.warningLight : AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: count > 0 ? AppColors.warningDark : AppColors.successDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (orders.isEmpty) ...[
            const SizedBox(height: 16),
            Center(child: Text('No pending orders', style: AppTextStyles.bodySmall)),
          ] else ...[
            const SizedBox(height: 12),
            ...orders.take(10).map((o) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o['order_number'] ?? '', style: AppTextStyles.labelLarge),
                        Text(o['customer_name'] ?? '', style: AppTextStyles.bodySmall),
                        if (o['transport'] != null && o['transport'].toString().isNotEmpty)
                          Text('🚚 ${o['transport']}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${o['cases'] ?? 0} cases', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(o['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          o['status'] ?? '',
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'PENDING': return AppColors.warningLight;
      case 'CONFIRMED': return AppColors.accentLight;
      case 'DISPATCHED': return AppColors.successLight;
      default: return AppColors.neutral200;
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
