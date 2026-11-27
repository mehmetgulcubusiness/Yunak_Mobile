import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';
import 'charts.dart';

const _compare = {'today': 'düne göre', 'week': 'önceki 7 güne göre', 'month': 'geçen ayın aynı günlerine göre'};

class CashPage extends ConsumerStatefulWidget {
  const CashPage({super.key});
  @override
  ConsumerState<CashPage> createState() => _CashPageState();
}

class _CashPageState extends ConsumerState<CashPage> {
  late final Loader<Json> _cash = Loader(_fetch)..addListener(() => mounted ? setState(() {}) : null);
  String _key = '';
  bool _exporting = false;

  String get _period {
    final p = GoRouterState.of(context).uri.queryParameters['period'] ?? 'month';
    return const ['today', 'week', 'month'].contains(p) || RegExp(r'^\d{4}-\d{2}$').hasMatch(p) ? p : 'month';
  }

  Future<Json> _fetch() => ref.read(apiProvider).reports.cash(_period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_period != _key) {
      _key = _period;
      _cash.fetch = _fetch;
      _cash.load();
    }
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  String _periodTitle(Json? data) {
    final p = _period;
    if (p == 'today') return 'Bugün · ${formatDay(DateTime.now())}';
    if (p == 'week') return 'Son 7 gün';
    if (p == 'month') {
      final start = data?.m('period').s('start');
      return '${start == null ? formatMonth(DateTime.now()) : formatMonth(start)} (bugüne kadar)';
    }
    return monthLabel(p);
  }

  Widget _change(num? now, num? before, String compare, {bool dark = false}) {
    if (before == null || before == 0) {
      return Text((now ?? 0) > 0 ? 'Önceki dönemde teslim yok' : 'Henüz teslim yok', style: TextStyle(color: dark ? C.sideInk : C.muted, fontSize: 12.5));
    }
    final ratio = change(now, before)!;
    final (sign, color) = ratio > 0 ? ('▲', dark ? const Color(0xFF4ADE80) : C.ok) : (ratio < 0 ? ('▼', dark ? const Color(0xFFF87171) : C.bad) : ('■', C.muted));
    return Text('$sign %${ratio.abs()} $compare', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600));
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ref.read(apiProvider).reports.cashExport(_period);
      final dir = await getTemporaryDirectory();
      final name = file.fileName ?? 'kasa-$_period.csv';
      final path = '${dir.path}${Platform.pathSeparator}$name';
      await File(path).writeAsBytes(file.bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'text/csv')], subject: name));
    } catch (e) {
      toastError(e, 'Dosya hazırlanamadı.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _print(Json d) async {
    try {
      final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
      final firm = ref.read(sessionProvider).me?.tenant?.name ?? 'İşletme';
      final s = d.m('summary');
      final title = _periodTitle(d);
      await Printing.layoutPdf(
        name: 'Kasa',
        format: PdfPageFormat.a4,
        onLayout: (format) async {
          final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
          doc.addPage(pw.MultiPage(
            pageFormat: format,
            build: (_) => [
              pw.Text('$firm · Kasa · $title', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Basım: ${formatStamp(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(data: [
                ['Ciro', money(s.n('totalTry') ?? 0) ?? '0 ₺'],
                ['Teslim edilen iş', '${s.i('count')}'],
                ['Ortalama fiş', money(s.n('averageTry') ?? 0) ?? '0 ₺'],
                ['İçerideki iş', '${money(d.m('inside').n('totalTry') ?? 0)} · ${d.m('inside').i('count')} fiş'],
              ]),
              pw.SizedBox(height: 12),
              pw.Text('Hizmetlere göre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(headers: ['Hizmet', 'Fiş', 'Tutar'], data: [
                for (final r in d.l('periodServices').where((r) => r.i('count') > 0)) [serviceOf(r.s('serviceType')).title, '${r.i('count')}', money(r.n('totalTry') ?? 0) ?? ''],
              ]),
              pw.SizedBox(height: 12),
              pw.Text('Personel', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TableHelper.fromTextArray(headers: ['Personel', 'Açtığı fiş', 'Teslim ettiği', 'Teslim tutarı'], data: [
                for (final r in d.l('periodStaff')) [r.s('name') ?? 'Ortak hesap', '${r.i('opened')}', '${r.i('delivered')}', money(r.n('deliveredTry') ?? 0) ?? ''],
              ]),
            ],
          ));
          return doc.save();
        },
      );
    } catch (_) {
      toast('Yazdırılamadı.', tone: ToastTone.bad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _cash.data;
    final period = _period;
    final compare = _compare[period] ?? 'bir önceki aya göre';
    final s = d?.m('summary') ?? const <String, dynamic>{};
    final prev = s.m('previous');
    final inside = d?.m('inside') ?? const <String, dynamic>{};
    final thisMonth = istanbulDayKey(DateTime.now()).substring(0, 7);
    final pastMonths = (d?.l('months') ?? const <Json>[]).where((m) => m.str('month').compareTo(thisMonth) < 0).toList();
    return OpsPage(
      title: 'Kasa',
      subtitle: _periodTitle(d),
      onRefresh: () => _cash.load(silent: true),
      actions: [
        OutlinedButton.icon(onPressed: _exporting ? null : _export, icon: const AppIcon('note', size: 16), label: Text(_exporting ? 'Hazırlanıyor…' : "Excel'e aktar")),
        OutlinedButton.icon(onPressed: d == null ? null : () => _print(d), icon: const AppIcon('print', size: 16), label: const Text('Yazdır')),
      ],
      children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedTabs<String>(
            items: const [('today', 'Bugün', null), ('week', 'Son 7 gün', null), ('month', 'Bu ay', null)],
            value: const ['today', 'week', 'month'].contains(period) ? period : '',
            onChanged: (p) => setQuery(context, {'period': p == 'month' ? null : p}),
          ),
          if (pastMonths.isNotEmpty)
            DropdownButton<String>(
              value: RegExp(r'^\d{4}-\d{2}$').hasMatch(period) ? period : null,
              hint: const Text('Geçmiş ay'),
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(10),
              items: [for (final m in pastMonths) DropdownMenuItem(value: m.str('month'), child: Text('${monthLabel(m.str('month'))} (${m.i('count')} teslim)'))],
              onChanged: (v) => setQuery(context, {'period': v}),
            ),
        ]),
        const SizedBox(height: 14),
        ListState(loading: _cash.loading, hasData: d != null, count: 1, error: _cash.error, stale: _cash.stale, onRetry: () => _cash.load()),
        if (d == null && _cash.loading) const CardSkeleton(count: 2),
        if (d != null) ...[
          TileGrid(children: [
            _tile('Ciro', money(s.n('totalTry') ?? 0)!, _change(s.n('totalTry'), prev.n('totalTry'), compare, dark: true), dark: true),
            _tile('Teslim edilen iş', '${s.i('count')}', _change(s.n('count'), prev.n('count'), compare)),
            _tile('Ortalama fiş', money(s.n('averageTry') ?? 0)!, const Text('Teslim edilen iş başına', style: TextStyle(color: C.muted, fontSize: 12.5))),
            _tile('İçerideki iş', money(inside.n('totalTry') ?? 0)!, Text('${inside.i('count')} fiş henüz teslim edilmedi', style: const TextStyle(color: C.muted, fontSize: 12.5))),
          ]),
          const SizedBox(height: 14),
          if (s.i('unpriced') > 0) Notice('🚩 ${s.i('unpriced')} iş fiyatı girilmeden teslim edildi · ciroya 0 ₺ olarak girdi', tone: 'warn'),
          if (s.m('voided').i('count') > 0) Notice('🚩 ${s.m('voided').i('count')} teslim geçersiz sayıldı · ${money(s.m('voided').n('totalTry') ?? 0)} ciroya girmedi', tone: 'warn'),
          if (s.i('cancelled') > 0) Notice('🚩 ${s.i('cancelled')} iş iptal edildi', tone: 'warn'),
          _chart(d, period),
          LayoutBuilder(builder: (context, box) {
            final a = _services(d);
            final b = _staff(d);
            final c = _top(d);
            final e = _inside(inside);
            if (box.maxWidth > 860) {
              return Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)]),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: c), const SizedBox(width: 14), Expanded(child: e)]),
              ]);
            }
            return Column(children: [a, b, c, e]);
          }),
          const Text('Ciro teslim edilen işlerden hesaplanır. İptal edilen ve geçersiz sayılan fişler toplamlara girmez. Excel dosyasında telefon numarası yoktur.',
              style: TextStyle(color: C.muted, fontSize: 12.5)),
        ],
      ],
    );
  }

  Widget _tile(String label, String value, Widget sub, {bool dark = false}) => Panel(
        dark: dark,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trUpper(label), style: TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w600, color: dark ? C.sideInk : C.muted)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: dark ? Colors.white : C.ink, fontFeatures: tabular))),
          const SizedBox(height: 4),
          sub,
        ]),
      );

  Widget _chart(Json d, String period) {
    final days = d.l('chart');
    final today = istanbulDayKey(DateTime.now());
    final withSales = days.where((x) => x.i('count') > 0).length;
    final peak = days.fold<num>(0, (a, x) => (x.n('totalTry') ?? 0) > a ? x.n('totalTry')! : a);
    final cols = [
      for (final x in days)
        ColumnSpec(
          days.length <= 7 ? (x.str('day') == today ? 'Bugün' : formatWeekday(x.str('day'))) : '${int.tryParse(x.str('day').split('-').last) ?? ''}',
          (x.n('totalTry') ?? 0).toDouble(),
          tooltip: '${money(x.n('totalTry') ?? 0)} · ${formatDay('${x.str('day')}T12:00:00+03:00')} · ${x.i('count')} fiş',
          highlight: x.str('day') == today,
          faded: x.b('future'),
        ),
    ];
    return ChartPanel(
      title: period == 'today' ? 'Son 7 günün cirosu' : 'Günlük ciro',
      trailing: Text('$withSales günde teslim var', style: const TextStyle(color: C.muted, fontSize: 12.5)),
      chart: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (days.isEmpty) const Text('Bu dönemde teslim yok.', style: TextStyle(color: C.muted)) else ColumnChart(
          columns: cols,
          labelEvery: days.length <= 7 ? null : (i) => i == 0 || (i + 1) % 5 == 0 || i == days.length - 1,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('En yüksek gün: ${money(peak)}', style: const TextStyle(color: C.muted, fontSize: 12.5))),
          Container(width: 10, height: 10, color: C.gold),
          const SizedBox(width: 5),
          const Text('Bugün', style: TextStyle(color: C.muted, fontSize: 12.5)),
        ]),
      ]),
      table: DataRows(headers: const ['Gün', 'Fiş', 'Ciro'], numeric: const {1, 2}, rows: [
        for (final x in days.where((x) => !x.b('future'))) [formatDay('${x.str('day')}T12:00:00+03:00'), '${x.i('count')}', money(x.n('totalTry') ?? 0) ?? ''],
      ]),
    );
  }

  Widget _services(Json d) {
    final rows = d.l('periodServices').where((r) => r.i('count') > 0).toList();
    final total = rows.fold<num>(0, (a, r) => a + (r.n('totalTry') ?? 0));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Hizmetlere göre'),
        if (rows.isEmpty) const Text('Bu dönemde teslim edilen iş yok.', style: TextStyle(color: C.muted)),
        for (final r in rows) ...[
          Row(children: [
            AppIcon(serviceOf(r.s('serviceType')).icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(serviceOf(r.s('serviceType')).title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(money(r.n('totalTry') ?? 0) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: total == 0 ? 0 : (r.n('totalTry') ?? 0) / total, minHeight: 6, backgroundColor: C.chip, valueColor: const AlwaysStoppedAnimation(C.ink)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text('${r.i('count')} fiş · ortalama ${money(r.n('averageTry') ?? 0)} · cironun %${total == 0 ? 0 : (100 * (r.n('totalTry') ?? 0) / total).round()}\'i',
                style: const TextStyle(color: C.muted, fontSize: 12.5)),
          ),
        ],
      ]),
    );
  }

  Widget _staff(Json d) {
    final rows = d.l('periodStaff');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Personel'),
        if (rows.isEmpty)
          const Text('Bu dönemde personel hareketi yok.', style: TextStyle(color: C.muted))
        else
          DataRows(headers: const ['Personel', 'Açtığı fiş', 'Teslim ettiği', 'Teslim tutarı'], numeric: const {1, 2, 3}, rows: [
            for (final r in rows) [r.s('name') ?? 'Ortak hesap', '${r.i('opened')}', '${r.i('delivered')}', money(r.n('deliveredTry') ?? 0) ?? ''],
          ]),
      ]),
    );
  }

  Widget _top(Json d) {
    final rows = d.l('topCustomers');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('En çok kazandıran müşteriler'),
        if (rows.isEmpty) const Text('Bu dönemde tutarı girilmiş teslim yok.', style: TextStyle(color: C.muted)),
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: () => context.go(Uri(path: '/ops/musteriler', queryParameters: {'q': rows[i].str('name')}).toString()),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(color: C.muted, fontFeatures: tabular))),
                Expanded(child: Text(rows[i].str('name'), style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${rows[i].i('count')} fiş', style: const TextStyle(color: C.muted, fontSize: 12.5)),
                const SizedBox(width: 12),
                Text(money(rows[i].n('totalTry') ?? 0) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _inside(Json inside) {
    const labels = {'collected': 'Teslim alındı', 'washing': 'Yıkamada / işlemde', 'booked': 'Randevu bekleyen'};
    final oldest = inside.iOrNull('oldestDays');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('İçerideki iş'),
        for (final st in inside.l('stages'))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(labels[st.s('stage')] ?? st.str('stage'))),
              Text('${st.i('count')} fiş', style: const TextStyle(color: C.muted, fontSize: 12.5)),
              const SizedBox(width: 12),
              Text(money(st.n('totalTry') ?? 0) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        if (inside.i('unpriced') > 0)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('🚩 ${inside.i('unpriced')} açık işin fiyatı girilmedi; toplam eksik görünür.', style: const TextStyle(color: C.warn, fontSize: 13))),
        if (oldest != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('🕒 En eski fiş ${oldest == 0 ? 'bugün açıldı' : '$oldest gündür içeride'}.', style: const TextStyle(color: C.muted, fontSize: 13))),
      ]),
    );
  }
}
