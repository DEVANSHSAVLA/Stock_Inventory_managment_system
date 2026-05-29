import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final currentPath = GoRouterState.of(context).uri.path;

    final items = [
      _NavItem('/hub', 'Control Hub', Icons.grid_view_rounded, null),
      _NavItem('/dashboard', 'Dashboard', Icons.dashboard_outlined, null),
      _NavItem('/products', 'Products', Icons.inventory_outlined, null),
      if (user?.role == 'SALES' || user?.role == 'MANAGER' || user?.role == 'STAFF' || user?.role == 'ADMIN')
        _NavItem('/search', 'Search Products', Icons.search_rounded, null),
      if (user?.canCreateOrders == true) _NavItem('/orders', 'Orders', Icons.shopping_cart_outlined, null),
      _NavItem('/stock/in', 'Stock IN', Icons.arrow_downward_rounded, null),
      _NavItem('/stock/out', 'Stock OUT', Icons.arrow_upward_rounded, null),
      _NavItem('/stock/entries', 'Stock Entries', Icons.list_alt_outlined, null),
      _NavItem('/transfers', 'Transfers', Icons.swap_horiz_rounded, null),
      if (user?.canViewReports == true && user?.role != 'STAFF' && user?.role != 'WAREHOUSE' && user?.role != 'VIEWER')
        _NavItem('/reports', 'Reports', Icons.bar_chart_outlined, null),
      if (user?.canApprove == true) _NavItem('/suppliers', 'Suppliers', Icons.business_outlined, null),
      if (user?.canApprove == true) _NavItem('/purchase-orders', 'Purchase Orders', Icons.receipt_long_outlined, null),
      if (user?.canManageUsers == true) _NavItem('/users', 'Users', Icons.people_outline, null),
      _NavItem('/settings', 'Settings', Icons.settings_outlined, null),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('InventoryPro', style: AppTextStyles.headingMedium.copyWith(color: Colors.white)),
                        Text(user?.fullName ?? '', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isActive = currentPath == item.path;
                  return _DrawerTile(
                    item: item,
                    isActive: isActive,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(item.path);
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white60),
              title: Text('Sign Out', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final String label;
  final IconData icon;
  final String? badge;
  const _NavItem(this.path, this.label, this.icon, this.badge);
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerTile({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: AppColors.primary.withOpacity(0.25)) : null,
      ),
      child: ListTile(
        leading: Icon(item.icon, color: isActive ? AppColors.primary : Colors.white60, size: 22),
        title: Text(
          item.label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
