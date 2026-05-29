import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/utils/connectivity_handler.dart';
import '../../../core/storage/hive_service.dart';
import '../providers/stock_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/models/stock_model.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});
  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _formKey = GlobalKey<FormState>();
  VariantModel? _selectedVariant;
  LocationModel? _selectedLocation;
  final _qtyCtrl = TextEditingController(text: '1');
  final _casesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _expiryDate;
  DateTime? _entryDate = DateTime.now();
  bool _loading = false;
  List<VariantModel> _variants = [];
  String _variantSearch = '';

  @override
  void dispose() {
    _qtyCtrl.dispose(); _casesCtrl.dispose(); _priceCtrl.dispose(); _refCtrl.dispose();
    _batchCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchVariants(String search) async {
    try {
      final r = await DioClient().dio.get(ApiUrls.variants, queryParameters: {'search': search});
      setState(() {
        _variants = (r.data['data']['results'] as List)
            .map((e) => VariantModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVariant == null || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select variant and location'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    final isOnline = ref.read(isOnlineProvider);
    final data = {
      'variant': _selectedVariant!.id,
      'location': _selectedLocation!.id,
      'quantity': double.parse(_qtyCtrl.text),
      'cases': _casesCtrl.text.isNotEmpty ? double.parse(_casesCtrl.text) : null,
      'purchase_price': _priceCtrl.text.isNotEmpty ? double.parse(_priceCtrl.text) : null,
      'entry_date': (_entryDate ?? DateTime.now()).toIso8601String().split('T').first,
      'reference_number': _refCtrl.text,
      'batch_number': _batchCtrl.text.isEmpty ? null : _batchCtrl.text,
      'expiry_date': _expiryDate?.toIso8601String().split('T').first,
      'note': _noteCtrl.text,
      'entry_type': 'IN',
    };
    if (!isOnline) {
      await HiveService.savePendingEntry({...data, '_status': 'PENDING_SYNC'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved offline — will sync when online'), backgroundColor: AppColors.warning),
        );
        setState(() { _loading = false; });
        _resetForm();
      }
      return;
    }
    try {
      final entryData = Map<String, dynamic>.from(data)..remove('entry_type');
      await DioClient().dio.post(ApiUrls.stockIncoming, data: entryData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock IN entry submitted'), backgroundColor: AppColors.success),
        );
        ref.read(stockEntriesProvider.notifier).fetch();
        _resetForm();
      }
    } catch (e) {
      final errorMsg = _extractErrorMessage(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $errorMsg'), backgroundColor: AppColors.error),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _resetForm() {
    setState(() {
      _selectedVariant = null;
      _selectedLocation = null;
      _expiryDate = null;
      _entryDate = null;
    });
    _qtyCtrl.text = '1';
    _casesCtrl.clear(); _priceCtrl.clear();
    _refCtrl.clear(); _batchCtrl.clear(); _noteCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationsProvider);
    final locations = locState.maybeWhen(data: (d) => d, orElse: () => <LocationModel>[]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Stock IN'),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildForm(locations),
                  const SizedBox(height: 24),
                  _buildRecentEntries(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(List<LocationModel> locations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_downward_rounded, color: AppColors.successDark, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Log Stock IN', style: AppTextStyles.headingMedium),
              ],
            ),
            const SizedBox(height: 20),
            // Entry Date picker (Mandatory First Field)
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _entryDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _entryDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: _entryDate == null ? AppColors.error : AppColors.neutral200),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.neutral50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, color: AppColors.neutral400, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _entryDate != null
                          ? 'Entry Date: ${_entryDate!.toLocal().toString().split(' ').first}'
                          : 'Select Entry Date (Required)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _entryDate != null ? AppColors.neutral900 : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_entryDate == null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text('Date is required', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ),
            const SizedBox(height: 16),
            // Variant search
            TextFormField(
              decoration: _dec('Search Variant (name/SKU)', Icons.search_rounded).copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () async {
                    final result = await context.push<String>('/barcode-scanner');
                    if (result != null) {
                      await _fetchVariants(result);
                    }
                  },
                ),
              ),
              onChanged: (v) {
                _variantSearch = v;
                if (v.length > 1) _fetchVariants(v);
              },
            ),
            if (_variants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _variants.length,
                  itemBuilder: (ctx, i) {
                    final v = _variants[i];
                    return ListTile(
                      dense: true,
                      title: Text(v.displayName, style: AppTextStyles.labelLarge),
                      subtitle: Text(v.sku, style: AppTextStyles.bodySmall),
                      onTap: () => setState(() { _selectedVariant = v; _variants = []; }),
                    );
                  },
                ),
              ),
            ],
            if (_selectedVariant != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedVariant!.driveImageUrl != null)
                      Container(
                        width: 40, height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(_selectedVariant!.driveImageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40, height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppColors.neutral200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported, size: 20, color: AppColors.neutral500),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.successDark, size: 16),
                              const SizedBox(width: 4),
                              Expanded(child: Text(_selectedVariant!.displayName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.successDark))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Case Qty: ${_selectedVariant!.caseQuantity} pcs | Weight: ${_selectedVariant!.caseWeight ?? 'N/A'} kg | Dim: ${_selectedVariant!.caseDimension ?? 'N/A'}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.successDark),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppColors.successDark),
                      onPressed: () => setState(() => _selectedVariant = null),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<LocationModel>(
              value: _selectedLocation,
              decoration: _dec('Location', Icons.location_on_outlined),
              items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
              onChanged: (v) => setState(() => _selectedLocation = v),
              validator: (v) => v == null ? 'Select location' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _casesCtrl,
              decoration: _dec('Cases (optional)', Icons.all_inbox_rounded),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final cases = double.tryParse(v);
                if (cases != null && _selectedVariant != null) {
                  // Auto-calc pcs using variant's actual case quantity
                  final caseQty = _selectedVariant!.caseQuantity;
                  _qtyCtrl.text = (cases * caseQty).toStringAsFixed(0);
                }
              },
            ),
            if (_casesCtrl.text.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  '= ${_qtyCtrl.text} pcs',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyCtrl,
              decoration: _dec('Quantity (pcs)', Icons.numbers_rounded),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter valid quantity',
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              decoration: _dec('Add Price (Purchase Price)', Icons.attach_money_rounded),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refCtrl,
              decoration: _dec('Reference Number (optional)', Icons.receipt_outlined),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _batchCtrl,
              decoration: _dec('Batch Number (optional)', Icons.batch_prediction_outlined),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 180)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                setState(() => _expiryDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.neutral400, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _expiryDate != null ? 'Expiry: ${_expiryDate!.toLocal().toString().split(' ').first}' : 'Expiry Date (optional)',
                      style: AppTextStyles.bodyMedium.copyWith(color: _expiryDate != null ? AppColors.neutral900 : AppColors.neutral400),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: _dec('Note (optional)', Icons.note_outlined),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.arrow_downward_rounded),
                label: Text(_loading ? 'Submitting...' : 'Submit Stock IN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEntries() {
    final state = ref.watch(stockEntriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's IN Entries", style: AppTextStyles.headingMedium),
        const SizedBox(height: 12),
        state.when(
          data: (entries) {
            final inEntries = entries.where((e) => e.entryType == 'IN').take(10).toList();
            if (inEntries.isEmpty) return Center(child: Text('No entries today', style: AppTextStyles.bodySmall));
            return Column(
              children: inEntries.map((e) => _EntryRow(entry: e, canApprove: false)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading entries'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38),
    prefixIcon: Icon(icon, color: Colors.white38, size: 20),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  );
}

class _EntryRow extends ConsumerWidget {
  final StockEntryModel entry;
  final bool canApprove;
  const _EntryRow({required this.entry, required this.canApprove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.variantName, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${entry.locationName} • ${entry.loggedByName ?? ''}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${entry.quantity}', style: AppTextStyles.headingSmall.copyWith(color: AppColors.success)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.isApproved ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.isApproved ? 'Approved' : 'Pending',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: entry.isApproved ? AppColors.successDark : AppColors.warningDark,
                  ),
                ),
              ),
            ],
          ),
        ],
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
