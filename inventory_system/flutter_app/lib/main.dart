import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/storage/hive_service.dart';
import 'core/offline/sync_service.dart';

void main() async {
  debugPrint('--- [main] App entry point started ---');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- [main] WidgetsFlutterBinding initialized ---');
  
  try {
    debugPrint('--- [main] Initializing Hive... ---');
    await HiveService.init();
    debugPrint('--- [main] Hive initialized successfully ---');
  } catch (e) {
    debugPrint('--- [main] Hive initialization failed: $e ---');
  }

  // Set up conflict notification handler (logs to console by default;
  // screens can override SyncService().onConflict for SnackBar display).
  SyncService().onConflict = (msg) => debugPrint('[Conflict] $msg');

  debugPrint('--- [main] Running runApp ---');
  runApp(
    const ProviderScope(
      child: InventoryApp(),
    ),
  );
  debugPrint('--- [main] runApp completed ---');
}
