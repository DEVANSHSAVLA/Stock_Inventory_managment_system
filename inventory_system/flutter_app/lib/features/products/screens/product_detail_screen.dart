import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../core/utils/number_formatter.dart';
import '../../stock/providers/stock_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _productData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    try {
      final response = await DioClient().dio.get(ApiUrls.productDetail(widget.productId));
      if (response.data['success'] == true) {
        setState(() {
          _productData = response.data['data'];
          _loading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to fetch product';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showAdjustStockDialog(BuildContext context, int variantId, String variantName) {
    final locState = ref.read(locationsProvider);
    final locations = locState.maybeWhen(data: (d) => d, orElse: () => []);
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No locations available. Please add a location first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    int? selectedLocId = locations.first.id;
    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController(text: 'Stock Correction');
    final notesCtrl = TextEditingController();
    bool dialogSubmitting = false;
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Adjust Stock'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          variantName,
                          style: AppTextStyles.labelLarge.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedLocId,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: locations.map<DropdownMenuItem<int>>((loc) {
                            return DropdownMenuItem<int>(
                              value: loc.id,
                              child: Text(loc.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedLocId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: qtyCtrl,
                          decoration: InputDecoration(
                            labelText: 'Adjustment Quantity',
                            helperText: 'Use positive (e.g. 10) to add, negative (e.g. -5) to remove.',
                            prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final parsed = double.tryParse(v);
                            if (parsed == null || parsed == 0) return 'Must be a non-zero number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: reasonCtrl,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            prefixIcon: const Icon(Icons.question_mark_rounded, size: 20),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: dialogSubmitting
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setDialogState(() => dialogSubmitting = true);
                          try {
                            final res = await DioClient().dio.post('/api/stock/adjustment/', data: {
                              'variant': variantId,
                              'location': selectedLocId,
                              'quantity': double.parse(qtyCtrl.text),
                              'reason': reasonCtrl.text.trim(),
                              'notes': notesCtrl.text.trim(),
                            });
                            if (res.data['success'] == true) {
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              _fetchProductDetails();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.data['message'] ?? 'Stock adjusted successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              throw res.data['message'] ?? 'Failed to adjust stock';
                            }
                          } catch (e) {
                            setDialogState(() => dialogSubmitting = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: dialogSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Adjust'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _productData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Detail')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final name = _productData!['name'] ?? '';
    final category = _productData!['category'] ?? '';
    final unit = _productData!['unit_of_measure'] ?? '';
    final desc = _productData!['description'] ?? '';
    final isActive = _productData!['is_active'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarWidget(title: name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(name, category, unit, desc, isActive),
            const SizedBox(height: 24),
            Text('Variants', style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            ...[
              () {
                final variants = (_productData!['variants'] as List? ?? []);
                if (variants.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('No variants associated with this product.', style: AppTextStyles.bodyMedium),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: variants.length,
                  itemBuilder: (ctx, idx) {
                    final v = variants[idx];
                    final size = v['size'] ?? '';
                    final flavour = v['flavour'] ?? '';
                    final sku = v['sku'] ?? '';
                    final barcode = v['barcode'] ?? '';
                    final mrp = v['mrp'];
                    final weight = v['weight'];
                    final len = v['length'];
                    final wid = v['width'];
                    final hgt = v['height'];
                    final liveStock = v['live_stock'] ?? 0;
                    final displayName = '$size ${flavour.isNotEmpty ? flavour : ''}'.trim();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayName.isEmpty ? 'Default Variant' : displayName,
                                style: AppTextStyles.headingSmall,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: liveStock > 0 ? AppColors.stockGood : AppColors.stockLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Current Stock: ${NumberFormatter.formatQty(liveStock)} Units',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: liveStock > 0 ? AppColors.stockGoodText : AppColors.stockLowText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 12),
                          _detailRow('SKU', sku),
                          if (barcode.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _detailRow('Barcode', barcode),
                          ],
                          if (mrp != null) ...[
                            const SizedBox(height: 8),
                            _detailRow('MRP', NumberFormatter.formatCurrency(mrp)),
                          ],
                          if (weight != null) ...[
                            const SizedBox(height: 8),
                            _detailRow('Weight', '$weight kg'),
                          ],
                          if (len != null || wid != null || hgt != null) ...[
                            const SizedBox(height: 8),
                            _detailRow('Dimensions', '${len ?? 0} × ${wid ?? 0} × ${hgt ?? 0} cm'),
                          ],
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showAdjustStockDialog(context, v['id'], displayName.isEmpty ? 'Default Variant' : displayName),
                                icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryLight),
                                label: const Text('Adjust Stock', style: TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  backgroundColor: AppColors.primary.withOpacity(0.08),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }()
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String name, String category, String unit, String desc, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Details', style: AppTextStyles.headingSmall),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(6)),
                  child: Text('Inactive', style: AppTextStyles.labelSmall.copyWith(color: AppColors.errorDark)),
                )
            ],
          ),
          const Divider(height: 24),
          _detailRow('Category', category),
          const SizedBox(height: 12),
          _detailRow('Unit of Measure', unit),
          const SizedBox(height: 12),
          _detailRow('Description', desc.isEmpty ? 'N/A' : desc),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: AppTextStyles.labelLarge.copyWith(color: AppColors.neutral500))),
        Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}
