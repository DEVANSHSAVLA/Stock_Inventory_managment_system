import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _subdomainCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _companyCtrl.addListener(_autoSuggestSubdomain);
  }

  void _autoSuggestSubdomain() {
    final name = _companyCtrl.text.trim().toLowerCase();
    final subdomain = name.replaceAll(RegExp(r'[^a-z0-9]'), '-').replaceAll(RegExp(r'-+'), '-');
    if (_subdomainCtrl.text.isEmpty || _subdomainCtrl.text == _lastAutoSuggested) {
      _subdomainCtrl.text = subdomain;
      _lastAutoSuggested = subdomain;
    }
  }

  String _lastAutoSuggested = '';

  @override
  void dispose() {
    _companyCtrl.dispose();
    _subdomainCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(authProvider.notifier).signup(
      companyName: _companyCtrl.text.trim(),
      subdomain: _subdomainCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (mounted) {
      setState(() => _loading = false);
      if (!ok) {
        final error = ref.read(authProvider).error ?? 'Signup failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withOpacity(0.12),
              Colors.transparent,
            ],
            center: const Alignment(0, -0.5),
            radius: 1.2,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, size: 48, color: AppColors.primaryLight),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create Your Workspace',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your company inventory in 30 seconds',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white38),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 15)),
                    ],
                  ),
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Company Details', style: AppTextStyles.headingLarge),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _companyCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          decoration: _inputDecoration('Company Name', Icons.business_outlined),
                          validator: (v) => (v?.length ?? 0) >= 2 ? null : 'Company name required',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _subdomainCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          decoration: _inputDecoration('Workspace URL', Icons.link_outlined).copyWith(
                            suffixText: '.inventorypro.app',
                            suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 3) return 'Min 3 characters';
                            if (!RegExp(r'^[a-z0-9][a-z0-9-]*[a-z0-9]$').hasMatch(v)) return 'Letters, numbers, hyphens only';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),
                        Text('Admin Account', style: AppTextStyles.headingMedium),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Email address', Icons.email_outlined),
                          validator: (v) => v?.contains('@') == true ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white38),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v?.length ?? 0) >= 8 ? null : 'Min 8 characters',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
                          validator: (v) => v == _passCtrl.text ? null : 'Passwords do not match',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _agreed,
                              onChanged: (v) => setState(() => _agreed = v ?? false),
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Text(
                                'I agree to the Terms of Service and Privacy Policy',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('Create Workspace', style: AppTextStyles.headingSmall.copyWith(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have a workspace? ', style: AppTextStyles.bodySmall.copyWith(color: Colors.white38)),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Sign in',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Free plan includes 50 products, 5 users, 2 locations',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
