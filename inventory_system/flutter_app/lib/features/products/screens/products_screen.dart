import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/product_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/product_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/network/dio_client.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarWidget(
        title: 'Products',
        actions: [
          if (user?.canApprove == true)
            IconButton(
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              tooltip: 'Bulk Import',
              onPressed: () => _showBulkImport(context),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: user?.canApprove == true
          ? FloatingActionButton.extended(
              onPressed: () => _showAddVariant(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Variant'),
            )
          : null,
      body: Column(
        children: [
          _buildSearch(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(productsProvider.notifier).fetch(),
              child: state.when(
                data: (variants) {
                  if (variants.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.neutral300),
                          const SizedBox(height: 16),
                          Text('No products yet', style: AppTextStyles.headingMedium.copyWith(color: AppColors.neutral600)),
                          const SizedBox(height: 8),
                          Text('Add your first product to start tracking inventory', style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral400), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          if (ref.watch(authProvider).user?.canApprove == true)
                            ElevatedButton.icon(
                              onPressed: () => _showAddVariant(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your First Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: variants.length,
                    itemBuilder: (ctx, i) => _VariantCard(variant: variants[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: 'Search products, SKU...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
        onChanged: (v) => ref.read(productsProvider.notifier).fetch(search: v),
      ),
    );
  }

  void _showBulkImport(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Bulk Import'),
      content: const Text('Select an Excel file to import products and variants.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  void _showAddVariant(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        List<dynamic> products = [];
        bool loadingProducts = true;
        bool submitting = false;
        String? errorMessage;
        
        bool createNewProduct = false;
        int? selectedProductId;
        
        // Product controllers
        final prodNameCtrl = TextEditingController();
        final prodCatCtrl = TextEditingController();
        final prodUnitCtrl = TextEditingController(text: 'units');
        final prodImageUrlCtrl = TextEditingController();

        // Variant controllers
        final sizeCtrl = TextEditingController();
        final flavourCtrl = TextEditingController();
        final barcodeCtrl = TextEditingController();
        final reorderPtCtrl = TextEditingController(text: '10');
        final reorderQtyCtrl = TextEditingController(text: '50');
        final erpPriceCtrl = TextEditingController(text: '0.00');
        final mrpCtrl = TextEditingController(text: '');
        final weightCtrl = TextEditingController(text: '');
        final lengthCtrl = TextEditingController(text: '');
        final widthCtrl = TextEditingController(text: '');
        final heightCtrl = TextEditingController(text: '');
        final caseQtyCtrl = TextEditingController(text: '144');
        final caseWeightCtrl = TextEditingController(text: '');
        final caseDimensionCtrl = TextEditingController(text: '');
        final varImageUrlCtrl = TextEditingController();

        final formKey = GlobalKey<FormState>();

        Future<String?> _dialogPickAndUploadImage(StateSetter setDialogState) async {
          try {
            final result = await FilePicker.platform.pickFiles(type: FileType.image);
            if (result == null || result.files.isEmpty) return null;
            
            setDialogState(() {
              submitting = true;
              errorMessage = null;
            });

            final fileBytes = result.files.first.bytes;
            final fileName = result.files.first.name;

            final formData = dio_pkg.FormData();
            if (fileBytes != null) {
              formData.files.add(MapEntry(
                'file',
                dio_pkg.MultipartFile.fromBytes(fileBytes, filename: fileName),
              ));
            } else {
              final filePath = result.files.first.path;
              if (filePath != null) {
                formData.files.add(MapEntry(
                  'file',
                  await dio_pkg.MultipartFile.fromFile(filePath, filename: fileName),
                ));
              }
            }

            final res = await DioClient().dio.post('/api/products/upload-image/', data: formData);
            setDialogState(() => submitting = false);
            
            if (res.data['success'] == true) {
              return res.data['data']['url'] as String;
            } else {
              setDialogState(() {
                errorMessage = res.data['message'] ?? 'Upload failed';
              });
            }
          } catch (e) {
            setDialogState(() {
              submitting = false;
              errorMessage = 'Upload error: $e';
            });
          }
          return null;
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load products on first dialog render
            if (loadingProducts) {
              loadingProducts = false;
              DioClient().dio.get('/api/products/').then((res) {
                setDialogState(() {
                  products = res.data['data']['results'] ?? [];
                  if (products.isNotEmpty) {
                    selectedProductId = products.first['id'];
                  }
                });
              }).catchError((err) {
                setDialogState(() {
                  errorMessage = 'Failed to load products. You can create a new one instead.';
                });
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_box_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Add Variant', style: AppTextStyles.headingLarge),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Switch between selecting product and creating a new one
                        Row(
                          children: [
                            Checkbox(
                              value: createNewProduct,
                              activeColor: AppColors.primary,
                              onChanged: (v) {
                                setDialogState(() {
                                  createNewProduct = v ?? false;
                                });
                              },
                            ),
                            const Text('Create a brand new Product'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (createNewProduct) ...[
                          Text('New Product Details', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: prodNameCtrl,
                            decoration: _inputDecoration('Product Name', Icons.inventory_2_outlined),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Product name required' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: prodCatCtrl,
                            decoration: _inputDecoration('Category', Icons.category_outlined),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: prodUnitCtrl,
                            decoration: _inputDecoration('Unit of Measure', Icons.straighten_outlined),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Unit required' : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: prodImageUrlCtrl,
                                  decoration: _inputDecoration('Product Image URL', Icons.image_outlined),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.upload_file_rounded),
                                tooltip: 'Upload Product Image',
                                onPressed: () async {
                                  final url = await _dialogPickAndUploadImage(setDialogState);
                                  if (url != null) {
                                    prodImageUrlCtrl.text = url;
                                    setDialogState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          Text('Select Existing Product', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 8),
                          products.isEmpty
                              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                              : DropdownButtonFormField<int>(
                                  value: selectedProductId,
                                  decoration: _inputDecoration('Product', Icons.list_alt_rounded),
                                  items: products.map<DropdownMenuItem<int>>((p) {
                                    return DropdownMenuItem<int>(
                                      value: p['id'],
                                      child: Text(p['name'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    setDialogState(() {
                                      selectedProductId = v;
                                    });
                                  },
                                ),
                        ],
                        
                        const Divider(height: 32),
                        Text('Variant Properties', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: sizeCtrl,
                                decoration: _inputDecoration('Size (e.g. Large)', Icons.aspect_ratio_outlined),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: flavourCtrl,
                                decoration: _inputDecoration('Flavour / Color', Icons.color_lens_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: barcodeCtrl,
                          decoration: _inputDecoration('Barcode / UPC', Icons.qr_code_outlined),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: reorderPtCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Piece Quantity (Reorder Threshold)', Icons.warning_amber_rounded),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: reorderQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Reorder Quantity (Cases)', Icons.add_circle_outline_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: erpPriceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('ERP Price', Icons.currency_rupee_outlined),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: mrpCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('MRP', Icons.currency_rupee_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: weightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('Weight (kg)', Icons.monitor_weight_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text('Dimensions (L × W × H)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: lengthCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('Length', Icons.straighten_outlined),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: widthCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('Width', Icons.straighten_outlined),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: heightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('Height', Icons.straighten_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text('Case Packaging', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: caseQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Case Qty (pcs)', Icons.all_inbox_rounded),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: caseWeightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecoration('Case Weight (kg)', Icons.monitor_weight_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: caseDimensionCtrl,
                          decoration: _inputDecoration('Case Dimension (L×W×H)', Icons.straighten_outlined),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: varImageUrlCtrl,
                                decoration: _inputDecoration('Variant Image URL', Icons.image_outlined),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.upload_file_rounded),
                              tooltip: 'Upload Variant Image',
                              onPressed: () async {
                                final url = await _dialogPickAndUploadImage(setDialogState);
                                if (url != null) {
                                  varImageUrlCtrl.text = url;
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setDialogState(() {
                            submitting = true;
                            errorMessage = null;
                          });

                          try {
                            int? productId = selectedProductId;

                            // 1. Create a product first if requested
                            if (createNewProduct) {
                              final prodRes = await DioClient().dio.post('/api/products/', data: {
                                'name': prodNameCtrl.text.trim(),
                                'category': prodCatCtrl.text.trim(),
                                'unit_of_measure': prodUnitCtrl.text.trim(),
                                'drive_image_url': prodImageUrlCtrl.text.trim().isNotEmpty ? prodImageUrlCtrl.text.trim() : null,
                              });
                              productId = prodRes.data['data']['id'];
                            }

                            if (productId == null) {
                              throw 'Please select or create a valid product';
                            }

                            // 2. Create the variant
                            await DioClient().dio.post('/api/variants/', data: {
                              'product': productId,
                              'size': sizeCtrl.text.trim(),
                              'flavour': flavourCtrl.text.trim(),
                              'barcode': barcodeCtrl.text.trim(),
                              'reorder_point': int.tryParse(reorderPtCtrl.text) ?? 10,
                              'reorder_qty': int.tryParse(reorderQtyCtrl.text) ?? 50,
                              'erp_price': double.tryParse(erpPriceCtrl.text) ?? 0.0,
                              'mrp': double.tryParse(mrpCtrl.text),
                              'weight': double.tryParse(weightCtrl.text),
                              'length': double.tryParse(lengthCtrl.text),
                              'width': double.tryParse(widthCtrl.text),
                              'height': double.tryParse(heightCtrl.text),
                              'case_quantity': int.tryParse(caseQtyCtrl.text) ?? 144,
                              'case_weight': caseWeightCtrl.text.trim().isNotEmpty ? double.tryParse(caseWeightCtrl.text) : null,
                              'case_dimension': caseDimensionCtrl.text.trim().isNotEmpty ? caseDimensionCtrl.text.trim() : null,
                              'drive_image_url': varImageUrlCtrl.text.trim().isNotEmpty ? varImageUrlCtrl.text.trim() : null,
                            });

                            // Refresh list and close
                            ref.read(productsProvider.notifier).fetch();
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Variant added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              submitting = false;
                              errorMessage = 'Error saving variant: ${_extractErrorMessage(e)}';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Add Variant'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _VariantCard extends StatelessWidget {
  final VariantModel variant;
  const _VariantCard({required this.variant});

  @override
  Widget build(BuildContext context) {
    final stockColor = variant.liveStock == null ? AppColors.neutral200
        : variant.liveStock! <= variant.reorderPoint ? AppColors.stockLow
        : variant.liveStock! <= variant.reorderPoint * 2 ? AppColors.stockWarning
        : AppColors.stockGood;
    final stockTextColor = variant.liveStock == null ? AppColors.neutral500
        : variant.liveStock! <= variant.reorderPoint ? AppColors.stockLowText
        : variant.liveStock! <= variant.reorderPoint * 2 ? AppColors.stockWarningText
        : AppColors.stockGoodText;
    return InkWell(
      onTap: () => context.push('/products/${variant.productId}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.displayName, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(variant.sku, style: AppTextStyles.bodySmall),
                  if (!variant.isActive)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(4)),
                      child: Text('Inactive', style: AppTextStyles.labelSmall.copyWith(color: AppColors.errorDark)),
                    ),
                ],
              ),
            ),
            if (variant.liveStock != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: stockColor, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${variant.liveStock!.toStringAsFixed(0)}',
                  style: AppTextStyles.labelLarge.copyWith(color: stockTextColor, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _extractErrorMessage(dynamic e) {
  if (e is dio_pkg.DioException) {
    final response = e.response;
    if (response != null && response.data is Map) {
      final data = response.data;
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
      if (data['errors'] != null && data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
        final errors = data['errors'] as Map;
        final buffer = StringBuffer();
        errors.forEach((key, val) {
          buffer.write('$key: ');
          if (val is List) {
            buffer.write(val.join(', '));
          } else {
            buffer.write(val.toString());
          }
          buffer.write('\n');
        });
        return buffer.toString().trim();
      }
    }
    return e.message ?? e.toString();
  }
  return e.toString();
}
