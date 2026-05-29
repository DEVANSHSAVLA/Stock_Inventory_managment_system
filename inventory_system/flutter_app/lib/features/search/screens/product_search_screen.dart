import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/widgets/app_drawer.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});
  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 2) {
        _search(query);
      } else {
        setState(() => _results = []);
      }
    });
  }

  Future<void> _search(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() => _loading = true);
    try {
      final res = await DioClient().dio.get(
        ApiUrls.productSearch,
        queryParameters: {'q': query},
      );
      final data = res.data['data']['results'] as List<dynamic>;
      setState(() {
        _results = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Search Products'),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.white38),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _results = []; _lastQuery = ''; });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: AppColors.neutral300),
                        const SizedBox(height: 12),
                        Text('Search for products', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.neutral400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) => _buildResultCard(_results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final imageUrl = item['drive_image_url'] as String?;
    final sellingPrice = item['selling_price'];
    final availCases = item['available_cases'];
    final availPcs = item['available_pcs'];
    final bool isLow = (availPcs ?? 0) <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isLow ? AppColors.error.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Product image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _convertDriveUrl(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.primaryLight),
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['product_name'] ?? '',
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['size'] ?? ''} ${item['flavour'] ?? ''}'.trim(),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLow ? AppColors.stockLow : AppColors.stockGood,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${availCases ?? 0} cases',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isLow ? AppColors.stockLowText : AppColors.stockGoodText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${availPcs ?? 0} pcs', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            if (sellingPrice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormatter.formatCurrency(sellingPrice),
                    style: AppTextStyles.headingSmall.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                  ),
                  Text('per case', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: Colors.white38)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Convert Google Drive share links to direct view URLs.
  String _convertDriveUrl(String url) {
    final regex = RegExp(r'drive\.google\.com/file/d/([^/]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    }
    return url;
  }
}
