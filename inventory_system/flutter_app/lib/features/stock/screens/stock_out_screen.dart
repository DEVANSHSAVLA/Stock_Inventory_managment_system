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

class StockOutScreen extends ConsumerStatefulWidget {
  const StockOutScreen({super.key});
  @override
  ConsumerState<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends ConsumerState<StockOutScreen> {
  final _formKey = GlobalKey<FormState>();
  VariantModel? _selectedVariant;
  LocationModel? _selectedLocation;
  final _qtyCtrl = TextEditingController(text: '1');
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  List<VariantModel> _variants = [];

  @override
  void dispose() {
    _qtyCtrl.dispose(); _refCtrl.dispose(); _noteCtrl.dispose();
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
      'reference_number': _refCtrl.text,
      'note': _noteCtrl.text,
      'entry_type': 'OUT',
    };
    if (!isOnline) {
      await HiveService.savePendingEntry({...data, '_status': 'PENDING_SYNC'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved offline — will sync when online'), backgroundColor: AppColors.warning),
        );
        setState(() { _loading = false; });
        _reset();
      }
      return;
    }
    try {
      final d = Map<String, dynamic>.from(data)..remove('entry_type');
      await DioClient().dio.post(ApiUrls.stockOutgoing, data: d);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock OUT entry submitted'), backgroundColor: AppColors.success),
        );
        ref.read(stockEntriesProvider.notifier).fetch();
        _reset();
      }
    } catch (e) {
      final errorMsg = _extractErrorMessage(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $errorMsg'), backgroundColor: AppColors.error),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _reset() {
    setState(() { _selectedVariant = null; _selectedLocation = null; });
    _qtyCtrl.text = '1'; _refCtrl.clear(); _noteCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationsProvider);
    final locations = locState.maybeWhen(data: (d) => d, orElse: () => <LocationModel>[]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Stock OUT'),
      drawer: const AppDrawer(),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
              ),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_upward_rounded, color: AppColors.warningDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Log Stock OUT', style: AppTextStyles.headingMedium),
                ]),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: _dec('Search Variant', Icons.search_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () async {
                        final result = await context.push<String>('/barcode-scanner');
                        if (result != null) await _fetchVariants(result);
                      },
                    ),
                  ),
                  onChanged: (v) { if (v.length > 1) _fetchVariants(v); },
                ),
                if (_variants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.neutral200), borderRadius: BorderRadius.circular(12)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _variants.length,
                      itemBuilder: (ctx, i) {
                        final v = _variants[i];
                        return ListTile(dense: true, title: Text(v.displayName, style: AppTextStyles.labelLarge), subtitle: Text(v.sku, style: AppTextStyles.bodySmall), onTap: () => setState(() { _selectedVariant = v; _variants = []; }));
                      },
                    ),
                  ),
                ],
                if (_selectedVariant != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Expanded(child: Text(_selectedVariant!.displayName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.warningDark))),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.warningDark), onPressed: () => setState(() => _selectedVariant = null), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    ]),
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
                TextFormField(controller: _qtyCtrl, decoration: _dec('Quantity', Icons.numbers_rounded), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter valid quantity'),
                const SizedBox(height: 16),
                TextFormField(controller: _refCtrl, decoration: _dec('Reference Number (optional)', Icons.receipt_outlined)),
                const SizedBox(height: 16),
                TextFormField(controller: _noteCtrl, decoration: _dec('Note (optional)', Icons.note_outlined), maxLines: 2),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: Text(_loading ? 'Submitting...' : 'Submit Stock OUT'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ])),
            ),
          ]),
        )),
      ]),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38),
    prefixIcon: Icon(icon, color: Colors.white38, size: 20),
    filled: true, fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  );
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
