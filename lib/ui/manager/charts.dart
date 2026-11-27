import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/tokens.dart';
import '../widgets/common.dart';

/// Başlık + ipucu + Tablo/Grafik geçişi.
class ChartPanel extends StatefulWidget {
  const ChartPanel({super.key, required this.title, this.hint, required this.chart, this.table, this.trailing});
  final String title;
  final String? hint;
  final Widget chart;
  final Widget? table;
  final Widget? trailing;

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  bool _table = false;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(
            widget.title,
            sub: widget.hint,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ?widget.trailing,
              if (widget.table != null)
                TextButton(onPressed: () => setState(() => _table = !_table), child: Text(_table ? 'Grafik' : 'Tablo')),
            ]),
          ),
          _table && widget.table != null ? widget.table! : widget.chart,
        ]),
      );
}

class ColumnSpec {
  const ColumnSpec(this.label, this.value, {this.tooltip, this.highlight = false, this.faded = false});
  final String label;
  final double value;
  final String? tooltip;
  final bool highlight;
  final bool faded;
}

/// Dikey sütun grafiği; vurgulu sütun altın, soluk sütun gri.
class ColumnChart extends StatelessWidget {
  const ColumnChart({super.key, required this.columns, this.height = 200, this.showAxis = true, this.labelEvery});
  final List<ColumnSpec> columns;
  final double height;
  final bool showAxis;

  /// Ekseni kalabalık olmasın: yalnız bu indekslerde etiket.
  final bool Function(int index)? labelEvery;

  @override
  Widget build(BuildContext context) {
    final peak = columns.fold<double>(0, (a, c) => c.value > a ? c.value : a);
    final top = niceMax(peak);
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        maxY: top,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: showAxis, drawVerticalLine: false, horizontalInterval: top / 2, getDrawingHorizontalLine: (_) => const FlLine(color: C.lineSoft, strokeWidth: 1)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showAxis,
              reservedSize: 44,
              interval: top / 2,
              getTitlesWidget: (v, _) => Text(axisNumber(v), style: const TextStyle(fontSize: 10.5, color: C.muted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= columns.length) return const SizedBox.shrink();
                if (labelEvery != null && !labelEvery!(i)) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(columns[i].label, style: const TextStyle(fontSize: 10.5, color: C.muted)));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => C.ink,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItem: (group, _, _, _) {
              final c = columns[group.x];
              if (c.faded) return null;
              return BarTooltipItem(c.tooltip ?? axisNumber(c.value), const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500));
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < columns.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: columns[i].value > 0 ? (columns[i].value < top * .04 ? top * .04 : columns[i].value) : 0,
                width: columns.length > 20 ? 6 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: columns[i].faded ? C.lineSoft : (columns[i].highlight ? C.gold : C.ink),
              ),
            ]),
        ],
      )),
    );
  }
}

/// Yatay çubuk listesi.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.rows});
  final List<(String, double, String)> rows; // etiket, oran 0–1, sağdaki metin

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (label, ratio, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13, color: C.inkSoft))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: ratio <= 0 ? 0 : (ratio < .015 ? .015 : ratio), minHeight: 8, backgroundColor: C.chip, valueColor: const AlwaysStoppedAnimation(C.ink)),
                ),
              ),
              SizedBox(width: 92, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontFeatures: tabular))),
            ]),
          ),
      ]);
}

class Meter extends StatelessWidget {
  const Meter({super.key, required this.label, required this.value, this.note});
  final String label;
  final num? value;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), Text(percentText(value), style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: ((value ?? 0) / 100).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: C.chip, valueColor: const AlwaysStoppedAnimation(C.gold)),
          ),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(note!, style: const TextStyle(color: C.muted, fontSize: 12.5))),
        ]),
      );
}

/// KPI kutusu + yön oku (▲ ▼ ■) ve yazı; yön yalnız renkle verilmez.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.delta, this.compare, this.note, this.dark = false});
  final String label;
  final String value;
  final int? delta;
  final String? compare;
  final String? note;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    Widget? sub;
    if (delta != null) {
      final (sign, color) = delta! > 0 ? ('▲', dark ? const Color(0xFF4ADE80) : C.ok) : (delta! < 0 ? ('▼', dark ? const Color(0xFFF87171) : C.bad) : ('■', dark ? C.sideInk : C.muted));
      sub = Text('$sign %${delta!.abs()} ${compare ?? ''}'.trim(), style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600));
    } else if (note != null) {
      sub = Text(note!, style: TextStyle(color: dark ? C.sideInk : C.muted, fontSize: 12.5));
    }
    return Panel(
      dark: dark,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trUpper(label), style: TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w600, color: dark ? C.sideInk : C.muted)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: dark ? Colors.white : C.ink, fontFeatures: tabular, letterSpacing: -.4)),
        ),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: sub),
      ]),
    );
  }
}

/// Eşit genişlikte kutu ızgarası (telefonda 2 sütun).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.wideColumns = 4});
  final List<Widget> children;
  final int wideColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final per = box.maxWidth > 760 ? wideColumns : 2;
        final w = (box.maxWidth - (per - 1) * 10) / per;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

/// Basit veri tablosu (Tablo görünümü ve personel listeleri için).
class DataRows extends StatelessWidget {
  const DataRows({super.key, required this.headers, required this.rows, this.numeric = const {}});
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numeric;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          horizontalMargin: 4,
          columnSpacing: 22,
          headingTextStyle: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600),
          dataTextStyle: const TextStyle(fontSize: 13, color: C.ink, fontFeatures: tabular),
          columns: [for (var i = 0; i < headers.length; i++) DataColumn(label: Text(headers[i]), numeric: numeric.contains(i))],
          rows: [for (final r in rows) DataRow(cells: [for (final c in r) DataCell(Text(c))])],
        ),
      );
}
