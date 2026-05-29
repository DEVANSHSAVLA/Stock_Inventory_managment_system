import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/auth/providers/auth_provider.dart';

class AppBarWidget extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool isLive;
  final List<Widget>? actions;

  const AppBarWidget({
    super.key,
    required this.title,
    this.isLive = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      leading: title != 'Control Hub'
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/hub');
                }
              },
            )
          : null,
      title: Row(
        children: [
          Text(title, style: AppTextStyles.headingMedium.copyWith(color: Colors.white)),
          if (isLive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('LIVE', style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 9)),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        ...?actions,
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _RoleBadge(role: user.role),
          ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role == 'ADMIN' ? AppColors.roleAdmin
        : role == 'MANAGER' ? AppColors.roleManager
        : AppColors.roleStaff;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        role,
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
