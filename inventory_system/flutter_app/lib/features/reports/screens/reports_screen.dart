import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_bar_widget.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Reports', style: AppTextStyles.headingMedium.copyWith(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Movement'),
            Tab(text: 'Forecast'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DailyReportTab(),
          _WeeklyReportTab(),
          _MonthlyReportTab(),
          _MovementReportTab(),
          _ForecastReportTab(),
        ],
      ),
    );
  }
}

class _DailyReportTab extends StatefulWidget {
  const _DailyReportTab();
  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab> {
  DateTime _date = DateTime.now();
  List<dynamic> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormatter.formatApiDate(_date);
      final r = await DioClient().dio.get(ApiUrls.reportDaily, queryParameters: {'date': dateStr});
      setState(() { _rows = r.data['data']['rows'] as List; });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _export(String format) async {
    try {
      final dateStr = DateFormatter.formatApiDate(_date);
      await DioClient().dio.get(
        '${ApiUrls.reportExport}daily/',
        queryParameters: {'date': dateStr, 'format': format},
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$format exported')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) { setState(() => _date = d); _fetch(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.neutral200), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.neutral400),
                      const SizedBox(width: 8),
                      Text(DateFormatter.formatDate(_date), style: AppTextStyles.bodyMedium),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ExportBtn(label: 'PDF', onTap: () => _export('pdf')),
              const SizedBox(width: 8),
              _ExportBtn(label: 'Excel', onTap: () => _export('excel')),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(child: Text('No data for this date'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildTable(_rows),
                    ),
        ),
      ],
    );
  }

  Widget _buildTable(List<dynamic> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.neutral100),
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Variant')),
            DataColumn(label: Text('Opening'), numeric: true),
            DataColumn(label: Text('IN'), numeric: true),
            DataColumn(label: Text('OUT'), numeric: true),
            DataColumn(label: Text('Live Stock'), numeric: true),
          ],
          rows: rows.map((r) {
            final row = r as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(row['product']?.toString() ?? '', style: AppTextStyles.labelLarge)),
              DataCell(Text(row['variant']?.toString() ?? '', style: AppTextStyles.bodySmall)),
              DataCell(Text('${row['opening'] ?? 0}')),
              DataCell(Text('${row['total_in'] ?? 0}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
              DataCell(Text('${row['total_out'] ?? 0}', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600))),
              DataCell(Text('${row['live_stock'] ?? 0}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExportBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
      ),
    );
  }
}

class _WeeklyReportTab extends StatefulWidget {
  const _WeeklyReportTab();
  @override
  State<_WeeklyReportTab> createState() => _WeeklyReportTabState();
}

class _WeeklyReportTabState extends State<_WeeklyReportTab> {
  List<dynamic> _rows = [];
  bool _loading = false;
  String _period = '';

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.reportWeekly);
      setState(() {
        _rows = r.data['data']['rows'] as List;
        _period = '${r.data['data']['from_date']} to ${r.data['data']['to_date']}';
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            Text('Week: $_period', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            ..._rows.map((r) {
              final row = r as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row['product']?.toString() ?? '', style: AppTextStyles.labelLarge),
                  Text(row['variant']?.toString() ?? '', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _StatChip('IN', '${row['total_in'] ?? 0}', AppColors.success),
                    _StatChip('OUT', '${row['total_out'] ?? 0}', AppColors.warning),
                    _StatChip('NET', '${row['net'] ?? 0}', (double.tryParse(row['net']?.toString() ?? '') ?? 0.0) >= 0 ? AppColors.primary : AppColors.error),
                  ]),
                ]),
              );
            }),
          ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: AppTextStyles.headingSmall.copyWith(color: color)),
      Text(label, style: AppTextStyles.bodySmall),
    ]);
  }
}

class _MonthlyReportTab extends StatefulWidget {
  const _MonthlyReportTab();
  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}
class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  List<dynamic> _rows = [];
  bool _loading = false;
  @override
  void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.reportMonthly);
      setState(() { _rows = r.data['data']['rows'] as List; });
    } catch (_) {}
    setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: _rows.map((r) {
              final row = r as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row['product']?.toString() ?? '', style: AppTextStyles.labelLarge),
                  Text(row['variant']?.toString() ?? '', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _StatChip('IN', '${row['total_in'] ?? 0}', AppColors.success),
                    _StatChip('OUT', '${row['total_out'] ?? 0}', AppColors.warning),
                    _StatChip('NET', '${row['net'] ?? 0}', (double.tryParse(row['net']?.toString() ?? '') ?? 0.0) >= 0 ? AppColors.primary : AppColors.error),
                  ]),
                ]),
              );
            }).toList());
  }
}

class _MovementReportTab extends StatefulWidget {
  const _MovementReportTab();
  @override
  State<_MovementReportTab> createState() => _MovementReportTabState();
}
class _MovementReportTabState extends State<_MovementReportTab> {
  List<dynamic> _entries = [];
  bool _loading = false;
  @override
  void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await DioClient().dio.get(ApiUrls.reportMovement);
      setState(() { _entries = r.data['data']['results'] as List; });
    } catch (_) {}
    setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) {
    return _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: _entries.take(50).map((e) {
              final entry = e as Map<String, dynamic>;
              final isIn = entry['entry_type'] == 'IN';
              return Container(
                margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.neutral200)),
                child: Row(children: [
                  Container(
                    width: 6, height: 36,
                    decoration: BoxDecoration(color: isIn ? AppColors.success : AppColors.warning, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry['variant_name']?.toString() ?? '', style: AppTextStyles.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${entry['location_name']} • ${entry['logged_by_name'] ?? ''}', style: AppTextStyles.bodySmall),
                  ])),
                  Text('${isIn ? '+' : '-'}${entry['quantity']}', style: AppTextStyles.headingSmall.copyWith(color: isIn ? AppColors.success : AppColors.warning)),
                ]),
              );
            }).toList());
  }
}

class _ForecastReportTab extends StatefulWidget {
  const _ForecastReportTab();
  @override
  State<_ForecastReportTab> createState() => _ForecastReportTabState();
}
class _ForecastReportTabState extends State<_ForecastReportTab> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  final _variantIdCtrl = TextEditingController();

  @override
  void dispose() { _variantIdCtrl.dispose(); super.dispose(); }

  Future<void> _fetch(int variantId) async {
    setState(() { _loading = true; _data = null; });
    try {
      final r = await DioClient().dio.get(ApiUrls.reportForecast(variantId));
      setState(() { _data = r.data['data'] as Map<String, dynamic>; });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: TextField(
          controller: _variantIdCtrl,
          decoration: InputDecoration(labelText: 'Variant ID', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neutral200))),
          keyboardType: TextInputType.number,
        )),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () { final id = int.tryParse(_variantIdCtrl.text); if (id != null) _fetch(id); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
          child: const Text('Load'),
        ),
      ]),
      const SizedBox(height: 20),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_data != null) ...[
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.neutral200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Forecast: ${_data!['sku'] ?? ''}', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatChip('Live Stock', '${_data!['live_stock'] ?? 0}', AppColors.primary),
              _StatChip('Avg Daily', '${(double.tryParse(_data!['avg_daily_consumption']?.toString() ?? '') ?? 0.0).toStringAsFixed(1)}', AppColors.secondary),
              _StatChip('Days Left', _data!['days_remaining']?.toString() ?? '∞', (int.tryParse(_data!['days_remaining']?.toString() ?? '') ?? 999) < 7 ? AppColors.error : AppColors.success),
            ]),
            const SizedBox(height: 20),
            Text('30-Day Consumption', style: AppTextStyles.headingSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: LineChart(LineChartData(
                lineBarsData: [LineChartBarData(
                  spots: (_data!['daily_out_last_30'] as List).asMap().entries
                      .map((e) => FlSpot(e.key.toDouble(), double.tryParse(e.value?.toString() ?? '') ?? 0.0)).toList(),
                  isCurved: true, color: AppColors.secondary, dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.secondary.withOpacity(0.1)),
                )],
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, getTitlesWidget: (v, _) {
                    if (v % 5 == 0) return Text('D${v.toInt()}', style: AppTextStyles.labelSmall);
                    return const SizedBox.shrink();
                  })),
                ),
              )),
            ),
          ]),
        ),
      ],
    ]);
  }
}
