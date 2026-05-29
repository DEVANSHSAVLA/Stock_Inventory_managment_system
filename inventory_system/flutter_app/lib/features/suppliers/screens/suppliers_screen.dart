import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/supplier_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  List<SupplierModel> _suppliers = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.suppliers);
      setState(() {
        _suppliers = (r.data['data']['results'] as List)
            .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Suppliers'),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _suppliers.isEmpty
                ? const Center(child: Text('No suppliers found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _suppliers.length,
                    itemBuilder: (ctx, i) => _SupplierCard(supplier: _suppliers[i]),
                  ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  const _SupplierCard({required this.supplier});
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(supplier.name, style: AppTextStyles.headingSmall),
              Text(supplier.contactPerson, style: AppTextStyles.bodySmall),
            ])),
            if (!supplier.isActive) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
              child: Text('Inactive', style: AppTextStyles.labelSmall.copyWith(color: AppColors.errorDark)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.phone_outlined, size: 14, color: AppColors.neutral400),
            const SizedBox(width: 6),
            Text(supplier.phone.isEmpty ? 'N/A' : supplier.phone, style: AppTextStyles.bodySmall),
            const SizedBox(width: 16),
            Icon(Icons.email_outlined, size: 14, color: AppColors.neutral400),
            const SizedBox(width: 6),
            Expanded(child: Text(supplier.email.isEmpty ? 'N/A' : supplier.email, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ),
    );
  }
}
