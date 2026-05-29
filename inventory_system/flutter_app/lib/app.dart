import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/dashboard/screens/hub_screen.dart';
import 'features/products/screens/products_screen.dart';
import 'features/stock/screens/stock_in_screen.dart';
import 'features/stock/screens/stock_out_screen.dart';
import 'features/stock/screens/entries_screen.dart';
import 'features/stock/screens/barcode_scanner_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/suppliers/screens/suppliers_screen.dart';
import 'features/suppliers/screens/purchase_orders_screen.dart';
import 'features/transfers/screens/transfers_screen.dart';
import 'features/users/screens/users_screen.dart';
import 'features/products/screens/product_detail_screen.dart';
import 'features/tenants/screens/subscription_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/orders/screens/order_creation_screen.dart';
import 'features/search/screens/product_search_screen.dart';

/// Bridge between Riverpod [authProvider] and GoRouter's [refreshListenable].
/// GoRouter is created ONCE; this notifier tells it to re-evaluate redirects
/// whenever auth state changes — no more recreating the router instance.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      // Always read the CURRENT auth state (not a stale captured value)
      final authState = ref.read(authProvider);
      final status = authState.status;
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final isAuthPage = loc == '/login' || loc == '/signup';

      // Still initializing — stay on splash
      if (status == AuthStatus.unknown) {
        return onSplash ? null : '/splash';
      }

      // Not logged in — redirect to login (from splash or any protected page)
      if (status == AuthStatus.unauthenticated) {
        return isAuthPage ? null : '/login';
      }

      // Logged in — redirect away from splash/login/signup to dashboard
      if (status == AuthStatus.authenticated && (onSplash || isAuthPage)) {
        return '/hub';
      }

      return null; // no redirect needed
    },
    routes: [
      // ── Public routes ──────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (ctx, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, state) => const SignupScreen()),

      // ── Protected routes ──────────────────────────────────────────
      GoRoute(path: '/hub', builder: (ctx, state) => const HubScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, state) => const DashboardScreen()),
      GoRoute(path: '/products', builder: (ctx, state) => const ProductsScreen()),
      GoRoute(
        path: '/products/:id',
        builder: (ctx, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(path: '/stock/in', builder: (ctx, state) => const StockInScreen()),
      GoRoute(path: '/stock/out', builder: (ctx, state) => const StockOutScreen()),
      GoRoute(path: '/stock/entries', builder: (ctx, state) => const EntriesScreen()),
      GoRoute(path: '/barcode-scanner', builder: (ctx, state) => const BarcodeScannerScreen()),
      GoRoute(path: '/reports', builder: (ctx, state) => const ReportsScreen()),
      GoRoute(path: '/suppliers', builder: (ctx, state) => const SuppliersScreen()),
      GoRoute(path: '/purchase-orders', builder: (ctx, state) => const PurchaseOrdersScreen()),
      GoRoute(path: '/transfers', builder: (ctx, state) => const TransfersScreen()),
      GoRoute(path: '/users', builder: (ctx, state) => const UsersScreen()),
      GoRoute(path: '/subscription', builder: (ctx, state) => const SubscriptionScreen()),
      GoRoute(path: '/orders', builder: (ctx, state) => const OrdersScreen()),
      GoRoute(path: '/orders/new', builder: (ctx, state) => const OrderCreationScreen()),
      GoRoute(path: '/search', builder: (ctx, state) => const ProductSearchScreen()),
      GoRoute(path: '/settings', builder: (ctx, state) => const _SettingsScreen()),
    ],
  );
});

class InventoryApp extends ConsumerWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'InventoryPro',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
        ),
        cardTheme: CardTheme(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(title: 'Application', items: [
            _SettingsItem(icon: Icons.business_outlined, label: 'Company Name', value: 'InventoryPro'),
            _SettingsItem(icon: Icons.schedule_outlined, label: 'Timezone', value: 'IST (Asia/Kolkata)'),
            _SettingsItem(icon: Icons.info_outline_rounded, label: 'App Version', value: 'v2.0.0'),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Inventory', items: [
            _SettingsItem(icon: Icons.warning_amber_outlined, label: 'Default Reorder Threshold', value: '10 units'),
          ]),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(title, style: const TextStyle(color: AppColors.neutral500, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: items.asMap().entries.map((e) => Column(children: [
              ListTile(
                leading: Icon(e.value.icon, color: AppColors.primary, size: 20),
                title: Text(e.value.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                trailing: Text(e.value.value, style: const TextStyle(fontSize: 13, color: AppColors.neutral400)),
              ),
              if (e.key < items.length - 1) Divider(height: 1, indent: 56, color: Colors.white.withOpacity(0.06)),
            ])).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsItem({required this.icon, required this.label, required this.value});
}
