import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/user_model.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  List<UserModel> _users = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.users);
      setState(() {
        _users = (r.data['data']['results'] as List)
            .map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Users'),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUser(context),
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add User'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (ctx, i) => _UserCard(user: _users[i], onRefresh: _fetch),
              ),
      ),
    );
  }

  void _showAddUser(BuildContext context) {
    final _nameCtrl = TextEditingController();
    final _emailCtrl = TextEditingController();
    final _passCtrl = TextEditingController();
    String _role = 'STAFF';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Add User', style: AppTextStyles.headingMedium),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
        const SizedBox(height: 12),
        StatefulBuilder(builder: (ctx, setS) => DropdownButtonFormField<String>(
          value: _role,
          items: ['ADMIN', 'MANAGER', 'STAFF'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setS(() => _role = v!),
          decoration: const InputDecoration(labelText: 'Role'),
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            try {
              await DioClient().dio.post(ApiUrls.users, data: {
                'username': _nameCtrl.text, 'email': _emailCtrl.text,
                'password': _passCtrl.text, 'role': _role,
              });
              if (context.mounted) { Navigator.pop(ctx); _fetch(); }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
            }
          },
          child: const Text('Create'),
        ),
      ],
    ));
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  const _UserCard({required this.user, required this.onRefresh});

  Color get _roleColor => user.isAdmin ? AppColors.roleAdmin : user.isManager ? AppColors.roleManager : AppColors.roleStaff;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _roleColor.withOpacity(0.15), radius: 22,
            child: Text(
              user.fullName.trim().isNotEmpty ? user.fullName.trim().substring(0, 1).toUpperCase() : 'U',
              style: TextStyle(color: _roleColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName, style: AppTextStyles.labelLarge),
            Text(user.email, style: AppTextStyles.bodySmall),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(user.role, style: AppTextStyles.labelSmall.copyWith(color: _roleColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: user.isActive ? AppColors.success.withOpacity(0.2) : AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user.isActive ? 'Active' : 'Inactive',
                style: AppTextStyles.labelSmall.copyWith(
                  color: user.isActive ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
