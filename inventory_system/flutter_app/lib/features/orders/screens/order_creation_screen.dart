import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import 'package:dio/dio.dart' as dio_pkg;

class OrderCreationScreen extends ConsumerStatefulWidget {
  const OrderCreationScreen({super.key});

  @override
  ConsumerState<OrderCreationScreen> createState() => _OrderCreationScreenState();
}

class _OrderCreationScreenState extends ConsumerState<OrderCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _transportCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  List<Map<String, dynamic>> _selectedItems = [];
  bool _loading = false;
  List<dynamic> _locations = [];
  int? _selectedWarehouseId;
  bool _isDeliveredAtBooking = false;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiUrls.locations);
      setState(() {
        _locations = res.data['data']['results'];
      });
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAddressCtrl.dispose();
    _transportCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _selectedItems.add({
        'variant_id': null,
        'variant_name': '',
        'location_id': _locations.isNotEmpty ? _locations.first['id'] : null,
        'quantity': 1,
        'unit_price': 0.0,
        'available_stock': 0.0,
      });
    });
  }

  /// True if ANY line item has quantity exceeding available stock
  bool get _hasStockErrors {
    for (var item in _selectedItems) {
      if (item['variant_id'] != null && item['quantity'] > item['available_stock']) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    // Validate stock
    for (var item in _selectedItems) {
      if (item['variant_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product for all items')));
        return;
      }
      if (item['quantity'] > item['available_stock']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient stock for ${item['variant_name']}')));
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiUrls.orders, data: {
        'customer_name': _customerNameCtrl.text,
        'customer_phone': _customerPhoneCtrl.text,
        'customer_address': _customerAddressCtrl.text,
        'transport': _transportCtrl.text,
        'warehouse': _selectedWarehouseId,
        'is_delivered_at_booking': _isDeliveredAtBooking,
        'notes': _notesCtrl.text,
        'items': _selectedItems,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order created successfully'), backgroundColor: AppColors.success));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${_extractErrorMessage(e)}'), backgroundColor: AppColors.error));
      }
    }
  }

  Timer? _searchDebounceTimer;
  String _lastSearchQuery = '';
  List<Map<String, dynamic>> _lastSearchResults = [];

  Future<List<Map<String, dynamic>>> _searchVariants(String query) async {
    if (query.isEmpty) return [];
    if (query == _lastSearchQuery) return _lastSearchResults;
    
    final completer = Completer<List<Map<String, dynamic>>>();
    
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('${ApiUrls.variants}?search=$query&limit=20');
        final results = res.data['data']['results'] as List<dynamic>;
        
        _lastSearchQuery = query;
        _lastSearchResults = results.map((v) => {
          'id': v['id'],
          'name': '${v['product_name']} ${v['size']} ${v['flavour']}'.trim(),
        }).toList();
        
        completer.complete(_lastSearchResults);
      } catch (e) {
        completer.complete([]);
      }
    });
    
    return completer.future;
  }

  Future<void> _fetchLiveStock(int index, int variantId, int locationId) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('${ApiUrls.stockLiveVariant(variantId)}?location=$locationId');
      setState(() {
        _selectedItems[index]['available_stock'] = res.data['data']['live_stock'];
      });
    } catch (e) {
      debugPrint('Error fetching live stock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Create Order'),
      body: _locations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Customer Details', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerNameCtrl,
                    decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerAddressCtrl,
                    decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Text('Shipping & Logistics', style: AppTextStyles.headingMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _transportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Transport / Carrier',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Warehouse',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    value: _selectedWarehouseId,
                    items: _locations.map((loc) => DropdownMenuItem<int>(
                          value: loc['id'],
                          child: Text(loc['name']),
                        )).toList(),
                    onChanged: (val) => setState(() => _selectedWarehouseId = val),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Delivered Immediately (Walk-in)'),
                    value: _isDeliveredAtBooking,
                    onChanged: (bool? value) {
                      setState(() {
                        _isDeliveredAtBooking = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Items', style: AppTextStyles.headingMedium),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._selectedItems.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Internal Notes', prefixIcon: Icon(Icons.note_alt_outlined)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_loading || _hasStockErrors || _selectedItems.isEmpty) ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.neutral300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : Text(
                              _hasStockErrors ? 'Fix stock errors to continue' : 'Create Order & Reserve Stock',
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  if (_hasStockErrors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 6),
                          Text('One or more items exceed available stock', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemRow(int index, Map<String, dynamic> item) {
    final bool isOverAllocated = item['variant_id'] != null && item['quantity'] > item['available_stock'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: isOverAllocated ? AppColors.error : AppColors.neutral200, width: isOverAllocated ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (opt) => opt['name'],
                    optionsBuilder: (textEditingValue) => _searchVariants(textEditingValue.text),
                    onSelected: (opt) {
                      setState(() {
                        item['variant_id'] = opt['id'];
                        item['variant_name'] = opt['name'];
                      });
                      if (item['location_id'] != null) {
                        _fetchLiveStock(index, opt['id'], item['location_id']);
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Search Product', prefixIcon: Icon(Icons.search)),
                        validator: (v) => item['variant_id'] == null ? 'Required' : null,
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _selectedItems.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Location'),
                    value: item['location_id'],
                    items: _locations.map((loc) => DropdownMenuItem<int>(
                          value: loc['id'],
                          child: Text(loc['name']),
                        )).toList(),
                    onChanged: (val) {
                      setState(() => item['location_id'] = val);
                      if (item['variant_id'] != null && val != null) {
                        _fetchLiveStock(index, item['variant_id'], val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: (item['cases'] ?? 0).toString(),
                    decoration: const InputDecoration(labelText: 'Cases'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final cases = int.tryParse(v) ?? 0;
                      item['cases'] = cases;
                      // Auto-calc quantity from cases (144 pcs per case default)
                      if (cases > 0) {
                        setState(() => item['quantity'] = cases * 144.0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: item['quantity'].toString(),
                    decoration: const InputDecoration(labelText: 'Qty (pcs)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => item['quantity'] = double.tryParse(v) ?? 0,
                    validator: (v) {
                      final qty = double.tryParse(v ?? '') ?? 0;
                      if (qty <= 0) return '> 0';
                      if (qty > item['available_stock']) return 'Max: ${item['available_stock']}';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (item['variant_id'] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Available Stock: ', style: AppTextStyles.bodySmall),
                  Text('${item['available_stock']}', 
                    style: AppTextStyles.bodySmall.copyWith(
                      color: item['quantity'] > item['available_stock'] ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]
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
