import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';

class VariantMatrixScreen extends ConsumerStatefulWidget {
  const VariantMatrixScreen({super.key});
  @override
  ConsumerState<VariantMatrixScreen> createState() => _VariantMatrixScreenState();
}

class _VariantMatrixScreenState extends ConsumerState<VariantMatrixScreen> {
  Map<String, dynamic> _matrix = {};
  bool _loading = false;
  List<String> _allColumns = [];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.variantMatrix);
      final matrix = r.data['data']['matrix'] as Map<String, dynamic>;
      final colSet = <String>{};
      for (final variants in matrix.values) {
        colSet.addAll((variants as Map<String, dynamic>).keys);
      }
      setState(() {
        _matrix = matrix;
        _allColumns = colSet.toList()..sort();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBarWidget(title: 'Variant Matrix'),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _matrix.isEmpty
                ? const Center(child: Text('No variants found'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      child: _buildMatrix(),
                    ),
                  ),
      ),
    );
  }

  Widget _buildMatrix() {
    if (_matrix.isEmpty) return const SizedBox.shrink();
    final products = _matrix.keys.toList()..sort();
    return Table(
      border: TableBorder.all(color: AppColors.neutral200, width: 0.5),
      defaultColumnWidth: const FixedColumnWidth(110),
      columnWidths: {0: const FixedColumnWidth(180)},
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(color: AppColors.primary),
          children: [
            _headerCell('Product'),
            ..._allColumns.map((col) {
              final parts = col.split('|');
              return _headerCell('${parts[0]}\n${parts[1]}');
            }),
          ],
        ),
        // Data rows
        ...products.map((product) {
          final variants = _matrix[product] as Map<String, dynamic>;
          return TableRow(children: [
            _productCell(product),
            ..._allColumns.map((col) {
              final v = variants[col] as Map<String, dynamic>?;
              if (v == null) return _emptyCell();
              final stock = double.tryParse(v['live_stock']?.toString() ?? '') ?? 0.0;
              final reorder = int.tryParse(v['reorder_point']?.toString() ?? '') ?? 10;
              final color = stock <= reorder ? AppColors.stockLow
                  : stock <= reorder * 2 ? AppColors.stockWarning
                  : AppColors.stockGood;
              final textColor = stock <= reorder ? AppColors.stockLowText
                  : stock <= reorder * 2 ? AppColors.stockWarningText
                  : AppColors.stockGoodText;
              return _stockCell(stock.toStringAsFixed(0), color, textColor, v, context);
            }),
          ]);
        }),
      ],
    );
  }

  TableCell _headerCell(String text) => TableCell(
    child: Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(text, style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ),
  );

  TableCell _productCell(String name) => TableCell(
    child: Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.neutral100,
      child: Text(name, style: AppTextStyles.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );

  TableCell _emptyCell() => TableCell(
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: AppColors.neutral50,
      child: Text('-', style: AppTextStyles.bodySmall),
    ),
  );

  TableCell _stockCell(String stock, Color bg, Color textColor, Map<String, dynamic> variant, BuildContext context) => TableCell(
    child: GestureDetector(
      onTap: () => _showQuickEntry(context, variant),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        color: bg,
        child: Text(stock, style: AppTextStyles.headingSmall.copyWith(color: textColor)),
      ),
    ),
  );

  void _showQuickEntry(BuildContext ctx, Map<String, dynamic> variant) {
    final variantId = int.tryParse(variant['variant_id']?.toString() ?? '') ?? 0;
    final sku = variant['sku'] as String;
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quick Entry: $sku', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          Text('Current Stock: ${variant['live_stock']}', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); Navigator.pushNamed(ctx, '/stock/in'); },
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('Log IN'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); Navigator.pushNamed(ctx, '/stock/out'); },
              icon: const Icon(Icons.arrow_upward_rounded),
              label: const Text('Log OUT'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
