import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/stock_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/stock_model.dart';
import '../../../features/auth/providers/auth_provider.dart';

class EntriesScreen extends ConsumerStatefulWidget {
  const EntriesScreen({super.key});
  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen> {
  String? _filterType;
  bool? _filterApproved;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockEntriesProvider);
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Stock Entries'),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(stockEntriesProvider.notifier).fetch(),
              child: state.when(
                data: (entries) {
                  var filtered = entries;
                  if (_filterType != null) filtered = filtered.where((e) => e.entryType == _filterType).toList();
                  if (_filterApproved != null) filtered = filtered.where((e) => e.isApproved == _filterApproved).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No entries found'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _EntryCard(
                      entry: filtered[i],
                      canApprove: user?.canApprove == true,
                      onApprove: () => ref.read(stockEntriesProvider.notifier).approve(filtered[i].id),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          _FilterChip(label: 'IN', color: AppColors.success, selected: _filterType == 'IN', onTap: () => setState(() => _filterType = _filterType == 'IN' ? null : 'IN')),
          const SizedBox(width: 8),
          _FilterChip(label: 'OUT', color: AppColors.warning, selected: _filterType == 'OUT', onTap: () => setState(() => _filterType = _filterType == 'OUT' ? null : 'OUT')),
          const SizedBox(width: 8),
          _FilterChip(label: 'Approved', color: AppColors.primary, selected: _filterApproved == true, onTap: () => setState(() => _filterApproved = _filterApproved == true ? null : true)),
          const SizedBox(width: 8),
          _FilterChip(label: 'Pending', color: AppColors.error, selected: _filterApproved == false, onTap: () => setState(() => _filterApproved = _filterApproved == false ? null : false)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: selected ? Colors.white : color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final StockEntryModel entry;
  final bool canApprove;
  final Future<bool> Function() onApprove;
  const _EntryCard({required this.entry, required this.canApprove, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    final isIn = entry.entryType == 'IN';
    final dt = DateFormatter.parseApi(entry.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isIn ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(entry.entryType, style: AppTextStyles.labelSmall.copyWith(color: isIn ? AppColors.successDark : AppColors.warningDark, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.variantName, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${isIn ? '+' : '-'}${entry.quantity}', style: AppTextStyles.headingSmall.copyWith(color: isIn ? AppColors.success : AppColors.warning)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppColors.neutral400),
              const SizedBox(width: 4),
              Text(entry.locationName, style: AppTextStyles.bodySmall),
              const SizedBox(width: 12),
              Icon(Icons.person_outline, size: 14, color: AppColors.neutral400),
              const SizedBox(width: 4),
              Expanded(child: Text(entry.loggedByName ?? '', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(DateFormatter.formatDateTime(dt), style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.isApproved ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(entry.isApproved ? 'Approved' : 'Pending Approval',
                  style: AppTextStyles.labelSmall.copyWith(color: entry.isApproved ? AppColors.successDark : AppColors.warningDark)),
              ),
              if (canApprove && !entry.isApproved)
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.success, padding: EdgeInsets.zero),
                  onPressed: () async {
                    final ok = await onApprove();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Entry approved' : 'Failed to approve'),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
