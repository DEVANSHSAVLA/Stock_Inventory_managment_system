import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/supplier_model.dart';

final notificationsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await DioClient().dio.get(ApiUrls.notifications);
  return r.data['data'] as Map<String, dynamic>;
});

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final unread = state.maybeWhen(data: (d) => int.tryParse(d['unread_count']?.toString() ?? '') ?? 0, orElse: () => 0);
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => _showPanel(context, ref),
        ),
        if (unread > 0) Positioned(
          right: 8, top: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  void _showPanel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ProviderScope(parent: ProviderContainer(), child: _NotificationPanel(onReadAll: () async {
        try {
          await DioClient().dio.post(ApiUrls.notificationReadAll);
          ref.invalidate(notificationsProvider);
        } catch (_) {}
      })),
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  final VoidCallback onReadAll;
  const _NotificationPanel({required this.onReadAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Notifications', style: AppTextStyles.headingLarge),
            TextButton(onPressed: () { onReadAll(); Navigator.pop(context); }, child: const Text('Mark all read')),
          ]),
          const Divider(),
          Expanded(child: state.when(
            data: (data) {
              final items = data['results'] as List? ?? [];
              if (items.isEmpty) return const Center(child: Text('No notifications'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final n = NotificationModel.fromJson(items[i] as Map<String, dynamic>);
                  return _NotifTile(notification: n, onRead: () async {
                    try {
                      await DioClient().dio.post(ApiUrls.notificationRead(n.id));
                      ref.invalidate(notificationsProvider);
                    } catch (_) {}
                  });
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          )),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onRead;
  const _NotifTile({required this.notification, required this.onRead});

  IconData get _icon => notification.type == 'LOW_STOCK' ? Icons.warning_amber_rounded
      : notification.type == 'EXPIRY' ? Icons.event_busy_rounded
      : notification.type == 'APPROVAL' ? Icons.check_circle_outline
      : Icons.info_outline_rounded;

  Color get _color => notification.type == 'LOW_STOCK' ? AppColors.error
      : notification.type == 'EXPIRY' ? AppColors.warning
      : notification.type == 'APPROVAL' ? AppColors.success
      : AppColors.neutral400;

  @override
  Widget build(BuildContext context) {
    final dt = DateFormatter.parseApi(notification.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead ? AppColors.neutral50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: notification.isRead ? AppColors.neutral200 : _color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(_icon, color: _color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(notification.message, style: AppTextStyles.bodySmall.copyWith(color: notification.isRead ? AppColors.neutral500 : AppColors.neutral900), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(DateFormatter.timeAgo(dt), style: AppTextStyles.bodySmall),
        ])),
        if (!notification.isRead) IconButton(
          icon: const Icon(Icons.check, size: 16, color: AppColors.success),
          onPressed: onRead, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}
