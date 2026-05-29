import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../features/auth/providers/auth_provider.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final double width = MediaQuery.of(context).size.width;
    
    final int cols = width > 700 ? 2 : 1;
    final double ratio = width > 1200 ? 4.2 : (width > 700 ? 3.0 : 2.5);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Techy dark slate background
      appBar: const AppBarWidget(
        title: 'Control Hub',
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner Widget
              _buildWelcomeBanner(user?.fullName ?? 'Administrator'),
              const SizedBox(height: 24),

              // SECTION 1: SALES
              _buildSectionHeader('Sales Portal', Icons.trending_up_rounded, Colors.blueAccent),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ratio,
                children: [
                  _HubCard(
                    title: 'Live Stock',
                    description: 'Monitor real-time inventory counts across sizes and flavours.',
                    icon: Icons.analytics_outlined,
                    gradient: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Premium electric blue
                    onTap: () => context.go('/products'),
                  ),
                  _HubCard(
                    title: 'Pending for Delivery',
                    description: 'Track and manage booked orders waiting for shipping dispatch.',
                    icon: Icons.pending_actions_rounded,
                    gradient: const [Color(0xFF78350F), Color(0xFFD97706)], // Hot amber
                    onTap: () => context.go('/orders'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // SECTION 2: OFFICE / WAREHOUSE
              _buildSectionHeader('Office & Warehouse', Icons.business_center_rounded, Colors.greenAccent),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ratio,
                children: [
                  _HubCard(
                    title: 'Add Products',
                    description: 'Register new stock models, variants, and barcodes to the database.',
                    icon: Icons.add_circle_outline_rounded,
                    gradient: const [Color(0xFF064E3B), Color(0xFF10B981)], // Emerald green
                    onTap: () => context.go('/products'),
                  ),
                  _HubCard(
                    title: 'Update Delivery Status',
                    description: 'Update delivery stages, mark dispatched items, and log tracking IDs.',
                    icon: Icons.local_shipping_outlined,
                    gradient: const [Color(0xFF312E81), Color(0xFF6366F1)], // Tech indigo
                    onTap: () => context.go('/orders'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // SECTION 3: SHARED UTILITIES
              _buildSectionHeader('Operations & Booking', Icons.layers_rounded, Colors.purpleAccent),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ratio,
                children: [
                  _HubCard(
                    title: 'Search Products',
                    description: 'Quickly lookup variants, view ERP pricing, available cases, and SKU details.',
                    icon: Icons.search_rounded,
                    gradient: const [Color(0xFF4C1D95), Color(0xFF8B5CF6)], // High-tech violet
                    onTap: () => context.go('/search'),
                  ),
                  _HubCard(
                    title: 'Book Order',
                    description: 'Create new wholesale transactions, add customer orders, and allocate stock.',
                    icon: Icons.shopping_bag_outlined,
                    gradient: const [Color(0xFF0F766E), Color(0xFF06B6D4)], // Warm cyan
                    onTap: () => context.go('/orders/new'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withOpacity(0.3),
            child: Text(
              userName.trim().isNotEmpty ? userName.trim().substring(0, 1).toUpperCase() : 'A',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to InventoryPro',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.08),
            thickness: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -4.0, 0.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: widget.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.last.withOpacity(_isHovered ? 0.35 : 0.12),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0.0, 3.0),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
