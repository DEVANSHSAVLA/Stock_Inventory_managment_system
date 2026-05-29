import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/connectivity_handler.dart';
import '../../core/offline/sync_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Displays a warning banner when the user is offline.
/// Shows the count of pending actions queued for sync.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCount = SyncService().getPendingCount();

    // Show banner if offline OR if there are pending entries
    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    final String message = !isOnline
        ? 'You are offline — actions will sync when reconnected'
        : 'Syncing $pendingCount pending action${pendingCount == 1 ? '' : 's'}...';

    final Color bgColor = !isOnline ? AppColors.warning : AppColors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            !isOnline ? Icons.wifi_off_rounded : Icons.sync_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
            ),
          ),
          if (!isOnline)
            Text(
              '$pendingCount pending',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
