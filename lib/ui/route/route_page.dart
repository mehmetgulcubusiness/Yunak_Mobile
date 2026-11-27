import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/loader.dart';

String routeHref(List<String> addresses) {
  final stops = addresses.take(10).toList();
  final params = {'api': '1', 'destination': stops.last, 'travelmode': 'driving'};
  if (stops.length > 1) params['waypoints'] = stops.sublist(0, stops.length - 1).join('|');
  return Uri.https('www.google.com', '/maps/dir/', params).toString();
}

const _groups = [
  ('deliver', 'Teslime çıkacak', 'Yıkaması biten halı, yorgan ve perde. Kapıda tahsil edilecek tutar yanında.', 'Teslime çıkacak iş yok.'),
  ('visit', 'Koltuk randevuları', 'Müşterinin evinde yapılacak koltuk yıkama.', 'Bekleyen koltuk randevusu yok.'),
  ('pickup', 'Kapıdan alınacak', 'Henüz teslim alınmamış yeni fişler.', null),
];

class RoutePage extends ConsumerStatefulWidget {
  const RoutePage({super.key});
  @override
  ConsumerState<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends ConsumerState<RoutePage> {
  late final Loader<Json> _sheet = Loader(() => ref.read(apiProvider).reports.routeSheet())..addListener(_onLoad);
  late final AutoRefresh _auto = AutoRefresh(const Duration(seconds: 60), () => _sheet.load(silent: true));
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    _auto.touched();
    _sheet.load();
  }

  @override
  void dispose() {
    _auto.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _onLoad() {
    if (!mounted) return;
    final ids = _all.map((s) => s.id).toSet();
    setState(() => _picked.retainAll(ids));
  }

  List<RouteStop> _of(String key) => (_sheet.data ?? const {}).l(key).map(RouteStop.new).toList();
  List<RouteStop> get _all => [for (final g in _groups) ..._of(g.$1)];

  Future<void> _print() async {
    try {
      final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
      final name = ref.read(sessionProvider).me?.tenant?.name ?? 'İşletme';
      await Printing.layoutPdf(
        name: 'Servis listesi',
        format: PdfPageFormat.a4,
        onLayout: (format) async {
          final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
          doc.addPage(pw.MultiPage(
            pageFormat: format,
            build: (_) => [
              pw.Text('$name · Servis listesi', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(formatStamp(DateTime.now()), style: const pw.TextStyle(fontSize: 9)),
              for (final g in _groups)
                if (_of(g.$1).isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('${g.$2} (${_of(g.$1).length})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.TableHelper.fromTextArray(
                    headers: ['Fiş', 'Müşteri', 'Telefon', 'Adres', 'Tutar'],
                    data: [
                      for (final s in _of(g.$1)) ['#${s.reference}', s.customerName, displayPhone(s.phone), s.address.isEmpty ? '—' : s.address, money(s.amount) ?? '—'],
                    ],
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
            ],
          ));
          return doc.save();
        },
      );
    } catch (_) {
      toast('Liste yazdırılamadı.', tone: ToastTone.bad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _sheet.data;
    final all = _all;
    final picked = all.where((s) => _picked.contains(s.id)).toList();
    final total = picked.fold<num>(0, (a, s) => a + (s.amount ?? 0));
    return Column(children: [
      Expanded(
        child: OpsPage(
          title: 'Servis listesi',
          subtitle: 'Bugün araca binecek işler, adrese göre',
          actions: [OutlinedButton.icon(onPressed: data == null ? null : _print, icon: const AppIcon('print', size: 16), label: const Text('Yazdır'))],
          onRefresh: () => _sheet.load(silent: true),
          children: [
            ListState(
              loading: _sheet.loading,
              hasData: data != null,
              count: all.length,
              error: _sheet.error,
              stale: _sheet.stale,
              onRetry: () => _sheet.load(),
              empty: 'Araca binecek iş yok. Yıkaması biten işler burada görünür.',
            ),
            if (data == null && _sheet.loading) const CardSkeleton(),
            if (data != null && all.isNotEmpty)
              for (final g in _groups)
                if (g.$4 != null || _of(g.$1).isNotEmpty) _group(g, _of(g.$1)),
            if (data != null && all.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'İşin durumunu '),
                    TextSpan(text: 'İşler', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' ekranından ilerletin; teslim edilen iş bu listeden düşer.'),
                  ]),
                  style: TextStyle(color: C.muted, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      if (picked.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: C.side, boxShadow: Shadows.lift),
          child: SafeArea(
            top: false,
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, spacing: 8, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${picked.length} durak', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · ${money(total)} tahsilat${picked.length > 10 ? ' · Haritada ilk 10 durak açılır' : ''}'),
                ]),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(onPressed: () => setState(_picked.clear), style: TextButton.styleFrom(foregroundColor: C.sideInk), child: const Text('Seçimi temizle')),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.gold, foregroundColor: C.goldInk),
                  onPressed: () => openExternal(routeHref(picked.map((s) => s.address).toList())),
                  icon: const AppIcon('pin', size: 16, color: C.goldInk),
                  label: const Text('Haritada rota aç'),
                ),
              ]),
            ]),
          ),
        ),
    ]);
  }

  Widget _group((String, String, String, String?) g, List<RouteStop> stops) {
    final withAddress = stops.where((s) => s.address.isNotEmpty).map((s) => s.id).toList();
    final allPicked = withAddress.isNotEmpty && withAddress.every(_picked.contains);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          '${g.$2}  ${stops.length}',
          sub: g.$3,
          trailing: withAddress.isEmpty
              ? null
              : TextButton(
                  onPressed: () => setState(() => allPicked ? _picked.removeAll(withAddress) : _picked.addAll(withAddress)),
                  child: Text(allPicked ? 'Seçimi kaldır' : 'Hepsini seç'),
                ),
        ),
        if (stops.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(g.$4 ?? '', style: const TextStyle(color: C.muted))),
        for (final s in stops) _stop(s),
      ]),
    );
  }

  Widget _stop(RouteStop s) {
    final late = s.daysLate > 0;
    final service = serviceOf(s.serviceType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: late ? C.badBg : C.sunk, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: '${s.customerName} rotaya ekle',
          child: Checkbox(
            value: _picked.contains(s.id),
            onChanged: s.address.isEmpty ? null : (v) => setState(() => v == true ? _picked.add(s.id) : _picked.remove(s.id)),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(s.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('#${s.reference}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
              if (late) Pill('${s.daysLate} gün gecikti', tone: 'bad'),
            ]),
            const SizedBox(height: 4),
            if (s.address.isNotEmpty)
              InkWell(
                onTap: () => openMaps(s.address),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: AppIcon('pin', size: 14, color: C.muted)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(s.address, style: const TextStyle(fontSize: 13.5))),
                ]),
              )
            else
              const Text('Adres yok — müşteriyi arayın', style: TextStyle(color: C.bad, fontSize: 13)),
            const SizedBox(height: 4),
            Text([service.title, '${formatDay(s.createdAt)} açıldı', if ((s.note ?? '').trim().isNotEmpty) '• ${s.note!.trim()}'].join(' · '),
                style: const TextStyle(color: C.muted, fontSize: 12.5)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(s.amount) ?? 'Fiyat yok', style: TextStyle(fontWeight: FontWeight.w700, color: s.amount == null ? C.muted : C.ink)),
          IconButton(tooltip: 'Ara', onPressed: () => callPhone(s.phone), icon: const AppIcon('call', size: 18)),
        ]),
      ]),
    );
  }
}
