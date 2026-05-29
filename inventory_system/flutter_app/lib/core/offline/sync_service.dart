import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/hive_service.dart';
import '../network/dio_client.dart';
import '../constants/api_urls.dart';
import '../utils/connectivity_handler.dart';

/// Manages offline-first action queue and auto-sync on reconnect.
///
/// Flow:
/// 1. When offline, callers use [queueAction] to save actions to Hive.
/// 2. [SyncService] listens to connectivity changes via Riverpod.
/// 3. On reconnect, [syncPendingEntries] replays queued actions.
/// 4. Server state wins on conflict: if a 409/400 is returned,
///    the entry is discarded and the user is notified via callback.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;

  /// Callback invoked when a queued entry fails due to server conflict.
  /// The caller can use this to show a SnackBar or notification.
  void Function(String message)? onConflict;

  /// Queue an action locally when offline.
  /// [entry] must include 'entry_type' ('IN' or 'OUT') and all stock fields.
  Future<void> queueAction(Map<String, dynamic> entry) async {
    entry['_status'] = 'pending';
    entry['_queued_at'] = DateTime.now().toIso8601String();
    await HiveService.savePendingEntry(entry);
    debugPrint('[SyncService] Queued offline action (${entry['entry_type']})');
  }

  /// Replay all pending entries against the server.
  /// Returns the number of successfully synced entries.
  Future<int> syncPendingEntries() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    final pending = HiveService.getAllPendingEntries();
    if (pending.isEmpty) {
      _isSyncing = false;
      return 0;
    }

    debugPrint('[SyncService] Syncing ${pending.length} pending entries...');
    int synced = 0;
    int conflicts = 0;

    for (final entry in pending) {
      try {
        final data = Map<String, dynamic>.from(entry.value);
        final entryType = data['entry_type'] as String? ?? 'IN';
        final url = entryType == 'IN' ? ApiUrls.stockIncoming : ApiUrls.stockOutgoing;

        // Remove local-only metadata before sending
        data.remove('entry_type');
        data.remove('_status');
        data.remove('_queued_at');

        await DioClient().dio.post(url, data: data);
        await HiveService.deletePendingEntry(entry.key);
        synced++;
      } catch (e) {
        // If server explicitly rejects (400/409), discard the entry
        // (server state wins) and notify the caller.
        final statusCode = _extractStatusCode(e);
        if (statusCode != null && (statusCode == 400 || statusCode == 409)) {
          await HiveService.deletePendingEntry(entry.key);
          conflicts++;
          onConflict?.call(
            'A queued stock entry was rejected by the server (conflict). '
            'The server state has been preserved.',
          );
          debugPrint('[SyncService] Conflict detected, entry discarded');
        } else {
          // Transient error (network, 500) — leave in queue for next attempt
          debugPrint('[SyncService] Transient error syncing entry, will retry: $e');
        }
      }
    }

    debugPrint('[SyncService] Sync complete: $synced synced, $conflicts conflicts');
    _isSyncing = false;
    return synced;
  }

  int getPendingCount() {
    return HiveService.getAllPendingEntries().length;
  }

  int? _extractStatusCode(dynamic error) {
    try {
      // Works with DioException
      return (error as dynamic).response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }
}

/// Provider that auto-triggers sync when connectivity changes from offline → online.
final autoSyncProvider = Provider<void>((ref) {
  bool wasOffline = false;

  ref.listen<bool>(isOnlineProvider, (previous, next) {
    if (next && wasOffline) {
      debugPrint('[AutoSync] Back online — triggering sync');
      SyncService().syncPendingEntries().then((count) {
        if (count > 0) {
          debugPrint('[AutoSync] Synced $count entries');
        }
      });
    }
    wasOffline = !next;
  });
});
