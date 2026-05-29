import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Failsafe: if we're still on splash after 5 seconds, force navigate to login.
    // This guarantees the user is NEVER stuck on this screen regardless of any
    // provider, storage, or connectivity issue.
    _failsafe = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        debugPrint('[SplashScreen] Failsafe triggered — forcing navigation to /login');
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state — when it changes from unknown, GoRouter redirect fires
    ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('InventoryPro',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text('SaaS Inventory Platform',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

