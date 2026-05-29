import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/app_bar_widget.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  final int? variantId;

  const ProductFormScreen({super.key, this.productId, this.variantId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _isEdit = false;

  // Product fields
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'units');
  final _descCtrl = TextEditingController();
  final _productImageUrlCtrl = TextEditingController();

  // Variant fields
  final _sizeCtrl = TextEditingController();
  final _flavourCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _reorderPointCtrl = TextEditingController(text: '10');
  final _reorderQtyCtrl = TextEditingController(text: '50');
  final _erpPriceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _caseQtyCtrl = TextEditingController(text: '144');
  final _caseWeightCtrl = TextEditingController();
  final _caseDimensionCtrl = TextEditingController();
  final _variantImageUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.variantId != null) {
      _isEdit = true;
      _fetchVariant();
    } else if (widget.productId != null) {
      _fetchProduct();
    }
  }

  Future<void> _fetchProduct() async {
    try {
      final res = await DioClient().dio.get(ApiUrls.productDetail(widget.productId!));
      final d = res.data['data'];
      _nameCtrl.text = d['name'] ?? '';
      _categoryCtrl.text = d['category'] ?? '';
      _unitCtrl.text = d['unit_of_measure'] ?? '';
      _descCtrl.text = d['description'] ?? '';
      _productImageUrlCtrl.text = d['drive_image_url'] ?? '';
      setState(() => _isEdit = true);
    } catch (_) {}
  }

  Future<void> _fetchVariant() async {
    try {
      final res = await DioClient().dio.get('${ApiUrls.variants}${widget.variantId}/');
      final d = res.data['data'];
      _sizeCtrl.text = d['size'] ?? '';
      _flavourCtrl.text = d['flavour'] ?? '';
      _barcodeCtrl.text = d['barcode'] ?? '';
      _reorderPointCtrl.text = '${d['reorder_point'] ?? 10}';
      _reorderQtyCtrl.text = '${d['reorder_qty'] ?? 50}';
      _erpPriceCtrl.text = d['erp_price'] != null ? '${d['erp_price']}' : '';
      _mrpCtrl.text = d['mrp'] != null ? '${d['mrp']}' : '';
      _weightCtrl.text = d['weight'] != null ? '${d['weight']}' : '';
      _lengthCtrl.text = d['length'] != null ? '${d['length']}' : '';
      _widthCtrl.text = d['width'] != null ? '${d['width']}' : '';
      _heightCtrl.text = d['height'] != null ? '${d['height']}' : '';
      _caseQtyCtrl.text = '${d['case_quantity'] ?? 144}';
      _caseWeightCtrl.text = d['case_weight'] != null ? '${d['case_weight']}' : '';
      _caseDimensionCtrl.text = d['case_dimension'] ?? '';
      _variantImageUrlCtrl.text = d['drive_image_url'] ?? '';
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _categoryCtrl.dispose(); _unitCtrl.dispose();
    _descCtrl.dispose(); _productImageUrlCtrl.dispose();
    _sizeCtrl.dispose(); _flavourCtrl.dispose(); _barcodeCtrl.dispose();
    _reorderPointCtrl.dispose(); _reorderQtyCtrl.dispose();
    _erpPriceCtrl.dispose(); _mrpCtrl.dispose(); _weightCtrl.dispose();
    _lengthCtrl.dispose(); _widthCtrl.dispose(); _heightCtrl.dispose();
    _caseQtyCtrl.dispose(); _caseWeightCtrl.dispose(); _caseDimensionCtrl.dispose();
    _variantImageUrlCtrl.dispose();
    super.dispose();
  }

  Future<String?> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return null;
      
      setState(() => _loading = true);

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
      setState(() => _loading = false);
      
      if (res.data['success'] == true) {
        return res.data['data']['url'] as String;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Upload failed'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final dio = DioClient().dio;

      if (widget.variantId != null) {
        // Update variant
        await dio.put('${ApiUrls.variants}${widget.variantId}/', data: {
          'size': _sizeCtrl.text,
          'flavour': _flavourCtrl.text,
          'barcode': _barcodeCtrl.text,
          'reorder_point': int.tryParse(_reorderPointCtrl.text) ?? 10,
          'reorder_qty': int.tryParse(_reorderQtyCtrl.text) ?? 50,
          'erp_price': _erpPriceCtrl.text.isNotEmpty ? double.parse(_erpPriceCtrl.text) : null,
          'mrp': _mrpCtrl.text.isNotEmpty ? double.parse(_mrpCtrl.text) : null,
          'weight': _weightCtrl.text.isNotEmpty ? double.parse(_weightCtrl.text) : null,
          'length': _lengthCtrl.text.isNotEmpty ? double.parse(_lengthCtrl.text) : null,
          'width': _widthCtrl.text.isNotEmpty ? double.parse(_widthCtrl.text) : null,
          'height': _heightCtrl.text.isNotEmpty ? double.parse(_heightCtrl.text) : null,
          'case_quantity': int.tryParse(_caseQtyCtrl.text) ?? 144,
          'case_weight': _caseWeightCtrl.text.isNotEmpty ? double.parse(_caseWeightCtrl.text) : null,
          'case_dimension': _caseDimensionCtrl.text.isNotEmpty ? _caseDimensionCtrl.text : null,
          'drive_image_url': _variantImageUrlCtrl.text.isNotEmpty ? _variantImageUrlCtrl.text : null,
        });
      } else if (widget.productId != null) {
        // Update product
        await dio.put(ApiUrls.productDetail(widget.productId!), data: {
          'name': _nameCtrl.text,
          'category': _categoryCtrl.text,
          'unit_of_measure': _unitCtrl.text,
          'description': _descCtrl.text,
          'drive_image_url': _productImageUrlCtrl.text.isNotEmpty ? _productImageUrlCtrl.text : null,
        });
      } else {
        // Create new product
        await dio.post(ApiUrls.products, data: {
          'name': _nameCtrl.text,
          'category': _categoryCtrl.text,
          'unit_of_measure': _unitCtrl.text,
          'description': _descCtrl.text,
          'drive_image_url': _productImageUrlCtrl.text.isNotEmpty ? _productImageUrlCtrl.text : null,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully'), backgroundColor: AppColors.success),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${_extractErrorMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.neutral400, size: 20),
    filled: true,
    fillColor: AppColors.neutral50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neutral200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neutral200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final isVariant = widget.variantId != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarWidget(title: isVariant ? 'Edit Variant' : (_isEdit ? 'Edit Product' : 'New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isVariant) ...[
                Text('Product Info', style: AppTextStyles.headingMedium),
                const SizedBox(height: 16),
                TextFormField(controller: _nameCtrl, decoration: _dec('Product Name *', Icons.label_outline), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _categoryCtrl, decoration: _dec('Category', Icons.category_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: _unitCtrl, decoration: _dec('Unit of Measure', Icons.straighten_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: _descCtrl, decoration: _dec('Description', Icons.description_outlined), maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _productImageUrlCtrl,
                        decoration: _dec('Drive Image URL', Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.upload_file_rounded),
                      tooltip: 'Upload Image',
                      onPressed: () async {
                        final url = await _pickAndUploadImage();
                        if (url != null) {
                          _productImageUrlCtrl.text = url;
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (isVariant) ...[
                Text('Variant Details', style: AppTextStyles.headingMedium),
                const SizedBox(height: 16),
                TextFormField(controller: _sizeCtrl, decoration: _dec('Size', Icons.format_size_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: _flavourCtrl, decoration: _dec('Flavour', Icons.icecream_outlined)),
                const SizedBox(height: 12),
                TextFormField(controller: _barcodeCtrl, decoration: _dec('Barcode', Icons.qr_code_outlined)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _reorderPointCtrl, decoration: _dec('Piece Quantity (Reorder Threshold)', Icons.warning_amber_outlined), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _reorderQtyCtrl, decoration: _dec('Reorder Quantity (Cases)', Icons.repeat_outlined), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Pricing & Packaging', style: AppTextStyles.headingMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _erpPriceCtrl,
                        decoration: _dec('ERP Price', Icons.currency_rupee_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _mrpCtrl,
                        decoration: _dec('MRP', Icons.currency_rupee_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                if (_erpPriceCtrl.text.isNotEmpty) ...{
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Selling Price: ₹${(double.tryParse(_erpPriceCtrl.text) ?? 0) * 1.12}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                    ),
                  ),
                },
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightCtrl,
                        decoration: _dec('Weight (kg)', Icons.monitor_weight_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _caseQtyCtrl,
                        decoration: _dec('Case Quantity (pcs)', Icons.all_inbox_rounded),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Dimensions (L × W × H)', style: AppTextStyles.headingSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lengthCtrl,
                        decoration: _dec('L', Icons.straighten_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _widthCtrl,
                        decoration: _dec('W', Icons.straighten_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _heightCtrl,
                        decoration: _dec('H', Icons.straighten_outlined),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caseWeightCtrl,
                  decoration: _dec('Case Weight (kg)', Icons.monitor_weight_outlined),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _caseDimensionCtrl, decoration: _dec('Case Dimension (L×W×H)', Icons.straighten_outlined)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _variantImageUrlCtrl,
                        decoration: _dec('Drive Image URL', Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.upload_file_rounded),
                      tooltip: 'Upload Image',
                      onPressed: () async {
                        final url = await _pickAndUploadImage();
                        if (url != null) {
                          _variantImageUrlCtrl.text = url;
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_loading ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
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
