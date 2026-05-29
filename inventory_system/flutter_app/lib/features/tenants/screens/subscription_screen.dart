import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/widgets/app_drawer.dart';

final subscriptionProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/subscription/usage/');
  return res.data['data'] as Map<String, dynamic>;
});

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: const AppBarWidget(title: 'Billing & Plan'),
      drawer: const AppDrawer(),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading subscription: $e')),
        data: (data) => _buildContent(context, ref, data),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final plan = data['plan'] ?? 'FREE';
    final status = data['status'] ?? 'ACTIVE';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Plan', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(plan, style: AppTextStyles.displayMedium.copyWith(color: Colors.white)),
              const SizedBox(height: 16),
              if (plan == 'FREE')
                ElevatedButton(
                  onPressed: () => _showUpgradeModal(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  child: const Text('Upgrade to Pro'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Resource Usage', style: AppTextStyles.headingLarge),
        const SizedBox(height: 16),
        _UsageBar('Products', data['products']),
        const SizedBox(height: 16),
        _UsageBar('Users', data['users']),
        const SizedBox(height: 16),
        _UsageBar('Locations', data['locations']),
      ],
    );
  }

  void _showUpgradeModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UpgradeModal(parentContext: context, parentRef: ref),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;

  const _UsageBar(this.label, this.data);

  @override
  Widget build(BuildContext context) {
    final current = int.tryParse(data['current']?.toString() ?? '') ?? 0;
    final limit = int.tryParse(data['limit']?.toString() ?? '') ?? 0;
    final ratio = limit == 0 ? 0.0 : (current / limit).clamp(0.0, 1.0);
    final color = ratio > 0.9 ? AppColors.error : (ratio > 0.7 ? AppColors.warning : AppColors.secondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text('$current / ${limit == 0 ? "Unlimited" : limit}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: limit == 0 ? 0 : ratio,
          backgroundColor: AppColors.neutral200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _UpgradeModal extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef parentRef;
  const _UpgradeModal({required this.parentContext, required this.parentRef});

  @override
  State<_UpgradeModal> createState() => _UpgradeModalState();
}

class _UpgradeModalState extends State<_UpgradeModal> {
  bool _loading = false;

  Future<void> _upgrade() async {
    setState(() => _loading = true);
    try {
      final dio = widget.parentRef.read(dioProvider);
      await dio.post('/subscription/upgrade/', data: {'plan': 'PRO'});
      if (mounted) {
        Navigator.pop(context);
        widget.parentRef.invalidate(subscriptionProvider);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Successfully upgraded to Pro!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upgrade failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.rocket_launch_rounded, size: 60, color: AppColors.secondary),
          const SizedBox(height: 16),
          Text('Upgrade to Pro', style: AppTextStyles.headingLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Unlock 500 products, 25 users, and 10 locations. Get premium features and priority support.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.neutral500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _upgrade,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: _loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirm Upgrade — \$49/mo'),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
