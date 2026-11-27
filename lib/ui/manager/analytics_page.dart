import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/loader.dart';
import 'charts.dart';

const _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key, this.focusOverdue = false});
  final bool focusOverdue;
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  late final Loader<Json> _data = Loader(_fetch)..addListener(_onLoad);
  late final AutoRefresh _auto = AutoRefresh(const Duration(seconds: 120), () => _data.load(silent: true));
  final _overdueKey = GlobalKey();
  int _key = 0;
  bool _scrolled = false;

  int get _range {
    final r = int.tryParse(GoRouterState.of(context).uri.queryParameters['range'] ?? '');
    return r == 30 || r == 365 ? r! : 90;
  }

  Future<Json> _fetch() => ref.read(apiProvider).reports.analytics(_range);

  void _onLoad() {
    if (!mounted) return;
    setState(() {});
    final wantsOverdue = widget.focusOverdue || GoRouterState.of(context).uri.fragment == 'geciken' || GoRouterState.of(context).uri.queryParameters['focus'] == 'geciken';
    if (wantsOverdue && !_scrolled && _data.data != null) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _overdueKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _auto.touched();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_range != _key) {
      _key = _range;
      _data.fetch = _fetch;
      _data.load();
    }
  }

  @override
  void dispose() {
    _auto.dispose();
    _data.dispose();
    super.dispose();
  }

  String _bucketShort(String b, bool month) => month ? formatDateShortMonth('$b-15') : _dayMonth(b);
  String _bucketLong(String b, bool month) => month ? monthLabel(b) : '${_dayMonth(b)} haftası';
  String _dayMonth(String key) => formatDay('${key}T12:00:00+03:00').split(' ').take(2).join(' ');

  @override
  Widget build(BuildContext context) {
    final d = _data.data;
    final range = _range;
    return OpsPage(
      title: 'Analiz',
      subtitle: 'İşin nasıl gittiği: teslim süresi, geri gelen müşteri, puanlar ve yoğun saatler',
      onRefresh: () => _data.load(silent: true),
      actions: [
        SegmentedTabs<int>(
          items: const [(30, '30 gün', null), (90, '90 gün', null), (365, '12 ay', null)],
          value: range,
          onChanged: (r) => setQuery(context, {'range': r == 90 ? null : '$r'}),
        ),
      ],
      children: [
        ListState(loading: _data.loading, hasData: d != null, count: 1, error: _data.error, stale: _data.stale, onRetry: () => _data.load()),
        if (d == null && _data.loading) const CardSkeleton(count: 3),
        if (d != null) ..._body(d, range),
      ],
    );
  }

  List<Widget> _body(Json d, int range) {
    final month = d.m('range').s('granularity') == 'month';
    final compare = range == 365 ? 'önceki 12 aya göre' : 'önceki $range güne göre';
    final rev = d.m('revenue');
    final turn = d.m('turnaround');
    final cust = d.m('customers');
    final rat = d.m('ratings');
    final promise = turn.m('promiseDays');
    final avg = rat.n('average');
    final deltaRev = change(rev.n('totalTry'), rev.m('previous').n('totalTry'));
    final deltaCount = change(rev.n('count'), rev.m('previous').n('count'));
    return [
      TileGrid(wideColumns: 3, children: [
        StatTile(label: 'Ciro', value: money(rev.n('totalTry') ?? 0)!, delta: deltaRev, compare: compare, note: 'Önceki dönemde teslim yok', dark: true),
        StatTile(label: 'Teslim edilen iş', value: '${rev.i('count')}', delta: deltaCount, compare: compare, note: 'Önceki dönemde teslim yok'),
        StatTile(label: 'Zamanında teslim', value: percentText(turn.n('onTimeRate')), note: 'Söz: halı ${promise.iOrNull('carpet_wash') ?? 4} gün, koltuk ${promise.iOrNull('sofa_wash') ?? 7} gün'),
        StatTile(label: 'Ortalama teslim süresi', value: duration(turn.n('medianHours')), note: 'Fiş açılışından teslime (medyan)'),
        StatTile(label: 'Geri gelen müşteri', value: percentText(cust.n('repeatRate')), note: '${cust.i('active')} müşteriden ${cust.i('returning')} tanesi daha önce de geldi'),
        StatTile(
            label: 'Ortalama puan',
            value: avg == null ? '—' : '${decimalTr(avg)} ★',
            note: '${rat.i('count')} değerlendirme · 5 yıldız ${percentText(rat.n('promoterRate'))}'),
      ]),
      const SizedBox(height: 14),
      _revenue(rev, month),
      LayoutBuilder(builder: (context, box) {
        final a = _turnaround(turn);
        final b = _ratings(rat, month);
        if (box.maxWidth > 860) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)]);
        return Column(children: [a, b]);
      }),
      KeyedSubtree(key: _overdueKey, child: _overdue(d.m('overdue'))),
      LayoutBuilder(builder: (context, box) {
        final a = _customers(cust, d.m('losses'));
        final b = _heatmap(d.m('intake'));
        if (box.maxWidth > 860) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)]);
        return Column(children: [a, b]);
      }),
      _reactivation(d.m('reactivation')),
    ];
  }

  Widget _revenue(Json rev, bool month) {
    final series = rev.l('series');
    return ChartPanel(
      title: month ? 'Aylık ciro' : 'Haftalık ciro',
      hint: 'Teslim edilen ve geçersiz sayılmayan işler. Üzerine gelince tutar ve teslim sayısı görünür.',
      chart: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ColumnChart(columns: [
          for (var i = 0; i < series.length; i++)
            ColumnSpec(
              _bucketShort(series[i].str('bucket'), month),
              (series[i].n('totalTry') ?? 0).toDouble(),
              tooltip: '${_bucketLong(series[i].str('bucket'), month)}\n${money(series[i].n('totalTry') ?? 0)} · ${series[i].i('count')} teslim',
              highlight: i == series.length - 1,
            ),
        ], labelEvery: series.length > 8 ? (i) => i % (series.length ~/ 6 + 1) == 0 || i == series.length - 1 : null),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 10, height: 10, color: C.gold),
          const SizedBox(width: 6),
          Text(month ? 'Bu ay (devam ediyor)' : 'Bu hafta (devam ediyor)', style: const TextStyle(color: C.muted, fontSize: 12.5)),
        ]),
      ]),
      table: DataRows(headers: const ['Dönem', 'Teslim', 'Ciro'], numeric: const {1, 2}, rows: [
        for (final s in series) [_bucketLong(s.str('bucket'), month), '${s.i('count')}', money(s.n('totalTry') ?? 0) ?? ''],
      ]),
    );
  }

  Widget _turnaround(Json turn) {
    final buckets = turn.l('buckets');
    final total = buckets.fold<int>(0, (a, b) => a + b.i('count'));
    final byService = turn.l('byService');
    return ChartPanel(
      title: 'Teslim süresi',
      hint: '${turn.i('count')} teslim · ortalama ${duration(turn.n('averageHours'))}',
      chart: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BarList(rows: [
          for (final b in buckets) (b.str('label'), total == 0 ? 0.0 : b.i('count') / total, '${b.i('count')} iş · %${total == 0 ? 0 : (100 * b.i('count') / total).round()}'),
        ]),
        const SizedBox(height: 6),
        for (final s in byService)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              AppIcon(serviceOf(s.s('serviceType')).icon, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(serviceOf(s.s('serviceType')).title)),
              Text(duration(s.n('medianHours')), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text('${percentText(s.n('onTimeRate'))} zamanında', style: TextStyle(fontSize: 12.5, color: (s.n('onTimeRate') ?? 100) < 80 ? C.bad : C.muted)),
            ]),
          ),
      ]),
      table: DataRows(headers: const ['Hizmet', 'Teslim', 'Medyan süre', 'Zamanında'], numeric: const {1}, rows: [
        for (final s in byService) [serviceOf(s.s('serviceType')).title, '${s.i('count')}', duration(s.n('medianHours')), percentText(s.n('onTimeRate'))],
      ]),
    );
  }

  Widget _ratings(Json rat, bool month) {
    final series = rat.l('series');
    final hasAny = series.any((s) => s.n('average') != null);
    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++) series[i].n('average') == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), series[i].n('average')!.toDouble()),
    ];
    return ChartPanel(
      title: 'Puan eğilimi',
      hint: '5 yıldız ${percentText(rat.n('promoterRate'))} · 1–3 yıldız ${percentText(rat.n('detractorRate'))}',
      chart: !hasAny
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('Bu dönemde puan gelmedi.', style: TextStyle(color: C.muted)))
          : SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                minY: 1,
                maxY: 5,
                minX: 0,
                maxX: math.max(1, series.length - 1).toDouble(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 2, getDrawingHorizontalLine: (_) => const FlLine(color: C.lineSoft, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}★', style: const TextStyle(fontSize: 10.5, color: C.muted)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: math.max(1, series.length ~/ 5).toDouble(),
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= series.length || v != i.toDouble()) return const SizedBox.shrink();
                        return Text(_bucketShort(series[i].str('bucket'), month), style: const TextStyle(fontSize: 10.5, color: C.muted));
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => C.ink,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem('${_bucketLong(series[s.x.toInt()].str('bucket'), month)}\n${decimalTr(s.y)} ★ · ${series[s.x.toInt()].i('count')} puan',
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(spots: spots, isCurved: false, color: C.gold, barWidth: 2.5, dotData: const FlDotData(show: true)),
                ],
              )),
            ),
      table: DataRows(headers: const ['Dönem', 'Puan', 'Ortalama'], numeric: const {1}, rows: [
        for (final s in series) [_bucketLong(s.str('bucket'), month), '${s.i('count')}', s.n('average') == null ? '—' : '${decimalTr(s.n('average')!)} ★'],
      ]),
    );
  }

  Widget _overdue(Json o) {
    final items = o.l('items');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Geciken işler',
          sub: 'Teslim sözünü aşan açık fişler. Müşteriyi arayıp yeni bir gün verin; en eskisi en üstte.',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (o.i('count') > 0) Pill('${o.i('count')}', tone: 'bad'),
            TextButton.icon(onPressed: () => context.go('/ops/servis'), icon: const AppIcon('truck', size: 15), label: const Text('Servis listesi')),
          ]),
        ),
        if (items.isEmpty) const Notice('Geciken iş yok. Bütün açık fişler teslim sözü içinde.', tone: 'ok'),
        for (final it in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.sunk, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lineSoft)),
            child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '#${it.str('reference')}  ', style: const TextStyle(color: C.muted)),
                  TextSpan(text: it.str('customerName'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ])),
                Text('${formatDay(it.s('createdAt'))} açıldı · ${serviceOf(it.s('serviceType')).title} · ${statusLabels[it.s('status')] ?? it.str('status')}',
                    style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Pill('${it.i('daysLate')} gün', tone: 'bad'),
                const SizedBox(width: 10),
                Text(money(it.n('amount')) ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                TextButton(onPressed: () => callPhone(it.s('phone')), child: const Text('Ara')),
                TextButton(onPressed: () => context.go(Uri(path: '/ops', queryParameters: {'q': it.str('reference')}).toString()), child: const Text('İş kartı')),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _customers(Json c, Json losses) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Müşteriler', sub: 'Dönemde ${c.i('active')} müşteri teslim aldı'),
          Row(children: [
            for (final (k, v) in [('Yeni müşteri', '${c.i('newCustomers')}'), ('Geri gelen', '${c.i('returning')}'), ('Müşteri başına ömür boyu', money(c.n('averageLifetimeTry') ?? 0) ?? '—')])
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k, style: const TextStyle(color: C.muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          Meter(label: 'En az iki kez gelenlerin oranı', value: c.n('repeatRate'), note: 'Halı yılda bir-iki kez yıkanır; bu oran yükseldikçe reklam gideri düşer.'),
          Meter(
            label: 'İptal oranı',
            value: losses.n('cancelRate'),
            note: '${losses.i('opened')} fişten ${losses.i('cancelled')} iptal · ${losses.i('voided')} teslimat geçersiz sayıldı',
          ),
        ]),
      );

  Widget _heatmap(Json intake) {
    final grid = (intake['grid'] is List ? intake['grid'] as List : const []).map((r) => r is List ? r.map((v) => v is num ? v.toInt() : 0).toList() : <int>[]).toList();
    var first = 8, last = 20, peak = 0, peakDay = -1, peakHour = -1;
    for (var d = 0; d < grid.length; d++) {
      for (var h = 0; h < grid[d].length; h++) {
        final v = grid[d][h];
        if (v > 0) {
          first = math.min(first, h);
          last = math.max(last, h);
        }
        if (v > peak) {
          peak = v;
          peakDay = d;
          peakHour = h;
        }
      }
    }
    const levels = 4;
    int at(int d, int h) => d < grid.length && h < grid[d].length ? grid[d][h] : 0;
    final hours = [for (var h = first; h <= last; h++) h];
    return ChartPanel(
      title: 'Yoğun saatler',
      hint: peak > 0
          ? 'En yoğun: ${_days[peakDay]} ${peakHour.toString().padLeft(2, '0')}:00 ($peak fiş). Personeli ve servis aracını buna göre planlayın.'
          : 'Fişlerin açıldığı gün ve saat.',
      chart: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(width: 40),
            for (final h in hours) SizedBox(width: 24, child: Text(h % 2 == 0 ? '$h' : '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: C.muted))),
          ]),
          for (var d = 0; d < 7; d++)
            Row(children: [
              SizedBox(width: 40, child: Text(_days[d].substring(0, 3), style: const TextStyle(fontSize: 11.5, color: C.inkSoft))),
              for (final h in hours)
                Tooltip(
                  message: '${_days[d]} ${h.toString().padLeft(2, '0')}:00 · ${at(d, h)} fiş',
                  child: Container(
                    width: 21,
                    height: 21,
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: at(d, h) == 0 ? C.chip : C.gold.withValues(alpha: (peak == 0 ? 0 : (levels * at(d, h) / peak).ceil()) / levels),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
        ]),
      ),
      table: DataRows(headers: const ['Gün', 'Fiş', 'En yoğun saat'], numeric: const {1}, rows: [
        for (var d = 0; d < 7; d++)
          () {
            final row = d < grid.length ? grid[d] : <int>[];
            final total = row.fold<int>(0, (a, b) => a + b);
            var best = -1, bestV = 0;
            for (var h = 0; h < row.length; h++) {
              if (row[h] > bestV) {
                bestV = row[h];
                best = h;
              }
            }
            return [_days[d], '$total', best < 0 ? '—' : '${best.toString().padLeft(2, '0')}:00 ($bestV fiş)'];
          }(),
      ]),
    );
  }

  Widget _reactivation(Json r) {
    final items = r.l('items');
    final firm = ref.read(sessionProvider).me?.tenant?.name ?? '';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Hatırlatma zamanı gelenler',
          sub: 'Son teslimatı ${r.i('afterDays', 180)} günden eski, mesajları açık müşteriler; en çok bırakan en üstte. WhatsApp düğmesi hazır bir mesajla açılır, göndermeden önce düzenleyebilirsiniz.',
          trailing: r.i('count') > 0 ? Pill('${r.i('count')}') : null,
        ),
        if (items.isEmpty) const Text('Şimdilik hatırlatılacak müşteri yok.', style: TextStyle(color: C.muted)),
        for (final c in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.sunk, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lineSoft)),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(c.str('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${displayPhone(c.s('phone'))} · Son teslim ${formatDay(c.s('lastOrderAt'))} (${c.i('daysSince')} gün önce)', style: const TextStyle(color: C.muted, fontSize: 12.5)),
                Text('${c.i('orderCount')} sipariş · ${money(c.n('totalTry') ?? 0)}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: () => openWhatsapp(
                    c.s('phone'),
                    'Merhaba ${c.str('name').split(' ').first}, $firm olarak yazıyoruz. Halı ve koltuklarınızın yıkama zamanı geldi; dilerseniz kapınızdan alalım. Uygun gününüzü yazmanız yeterli.',
                  ),
                  child: const Text("WhatsApp'tan hatırlat"),
                ),
                const SizedBox(width: 6),
                FilledButton(onPressed: () => context.go('/ops?fill=${Uri.encodeComponent(c.str('id'))}'), child: const Text('Yeni fiş')),
              ]),
            ]),
          ),
      ]),
    );
  }
}

/// "2026-11-15" → "Kas"
String formatDateShortMonth(String day) => formatDay('${day}T12:00:00+03:00').split(' ').length >= 2 ? formatDay('${day}T12:00:00+03:00').split(' ')[1] : day;
