import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/supplier_model.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});
  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  List<PurchaseOrderModel> _orders = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.purchaseOrders);
      setState(() {
        _orders = (r.data['data']['results'] as List)
            .map((e) => PurchaseOrderModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _receive(PurchaseOrderModel po) async {
    try {
      await DioClient().dio.post(ApiUrls.poReceive(po.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO received and stock entries created'), backgroundColor: AppColors.success));
      _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Purchase Orders'),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (ctx, i) => _POCard(po: _orders[i], onReceive: () => _receive(_orders[i])),
              ),
      ),
    );
  }
}

class _POCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final VoidCallback onReceive;
  const _POCard({required this.po, required this.onReceive});

  Color get _statusColor => po.status == 'RECEIVED' ? AppColors.success
      : po.status == 'SENT' ? AppColors.secondary : AppColors.neutral400;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PO-${po.id}', style: AppTextStyles.headingSmall),
            Text(po.supplierName, style: AppTextStyles.bodySmall),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(po.status, style: AppTextStyles.labelSmall.copyWith(color: _statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Items: ${po.items.length} • ${po.notes}', style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (po.status != 'RECEIVED') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReceive,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Mark as Received'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.success, side: const BorderSide(color: AppColors.success), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ]),
    );
  }
}
