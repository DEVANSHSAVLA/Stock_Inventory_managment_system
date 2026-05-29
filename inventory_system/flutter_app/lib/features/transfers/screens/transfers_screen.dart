import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import '../../../shared/models/stock_model.dart';
import '../../../features/stock/providers/stock_provider.dart';
import '../../../shared/models/product_model.dart';

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});
  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  List<StockTransferModel> _transfers = [];
  bool _loading = false;
  bool _showForm = false;

  final _formKey = GlobalKey<FormState>();
  LocationModel? _fromLoc, _toLoc;
  VariantModel? _variant;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  List<VariantModel> _variants = [];

  @override
  void initState() { super.initState(); _fetch(); }

  @override
  void dispose() { _qtyCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.transfers);
      setState(() {
        _transfers = (r.data['data']['results'] as List)
            .map((e) => StockTransferModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _fromLoc == null || _toLoc == null || _variant == null) return;
    try {
      await DioClient().dio.post(ApiUrls.transfers, data: {
        'from_location': _fromLoc!.id, 'to_location': _toLoc!.id,
        'variant': _variant!.id, 'quantity': double.parse(_qtyCtrl.text),
        'note': _noteCtrl.text,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer recorded'), backgroundColor: AppColors.success));
      setState(() { _showForm = false; _fromLoc = null; _toLoc = null; _variant = null; });
      _qtyCtrl.text = '1'; _noteCtrl.clear();
      _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationsProvider);
    final locations = locState.maybeWhen(data: (d) => d, orElse: () => <LocationModel>[]);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Transfers'),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showForm = !_showForm),
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        icon: Icon(_showForm ? Icons.close : Icons.add),
        label: Text(_showForm ? 'Cancel' : 'New Transfer'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_showForm) ...[
              _buildForm(locations),
              const SizedBox(height: 20),
            ],
            ..._transfers.map((t) => _TransferCard(transfer: t)),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<LocationModel> locations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New Transfer', style: AppTextStyles.headingMedium),
        const SizedBox(height: 16),
        DropdownButtonFormField<LocationModel>(
          value: _fromLoc, decoration: _dec('From Location', Icons.location_on_outlined),
          items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => _fromLoc = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LocationModel>(
          value: _toLoc, decoration: _dec('To Location', Icons.location_on_outlined),
          items: locations.where((l) => l.id != _fromLoc?.id).map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => _toLoc = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: _dec('Search Variant', Icons.search_rounded),
          onChanged: (v) async {
            if (v.length > 1) {
              final r = await DioClient().dio.get(ApiUrls.variants, queryParameters: {'search': v});
              setState(() { _variants = (r.data['data']['results'] as List).map((e) => VariantModel.fromJson(e as Map<String, dynamic>)).toList(); });
            }
          },
        ),
        if (_variants.isNotEmpty) Container(
          constraints: const BoxConstraints(maxHeight: 150), margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.08)), borderRadius: BorderRadius.circular(10)),
          child: ListView(children: _variants.map((v) => ListTile(dense: true, title: Text(v.displayName, style: AppTextStyles.labelLarge), onTap: () => setState(() { _variant = v; _variants = []; }))).toList()),
        ),
        if (_variant != null) Container(
          margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
          child: Text(_variant!.displayName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.successDark)),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _qtyCtrl, decoration: _dec('Quantity', Icons.numbers_rounded), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter valid quantity'),
        const SizedBox(height: 12),
        TextFormField(controller: _noteCtrl, decoration: _dec('Note (optional)', Icons.note_outlined), maxLines: 2),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Record Transfer'),
          ),
        ),
      ])),
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

class _TransferCard extends StatelessWidget {
  final StockTransferModel transfer;
  const _TransferCard({required this.transfer});
  @override
  Widget build(BuildContext context) {
    final dt = DateFormatter.parseApi(transfer.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(transfer.variantName, style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${transfer.quantity}', style: AppTextStyles.headingSmall.copyWith(color: AppColors.primary)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text(transfer.fromLocationName, style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral500)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.neutral400)),
          Text(transfer.toLocationName, style: AppTextStyles.bodySmall.copyWith(color: AppColors.neutral500)),
          const Spacer(),
          Text(DateFormatter.formatDateTime(dt), style: AppTextStyles.bodySmall),
        ]),
      ]),
    );
  }
}
