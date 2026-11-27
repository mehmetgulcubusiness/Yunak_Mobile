import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../shell/dashboard.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/loader.dart';

const _filters = ['all', 'unresolved', 'shield', 'google', 'resolved'];

class RatingsPage extends ConsumerStatefulWidget {
  const RatingsPage({super.key});
  @override
  ConsumerState<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends ConsumerState<RatingsPage> {
  late final Loader<RatingPage> _list = Loader(_fetch)..addListener(_onLoad);
  late final AutoRefresh _auto = AutoRefresh(const Duration(seconds: 60), () => _list.load(silent: true));
  final _scroll = ScrollController();
  String _key = '';
  final Set<String> _busy = {};

  Map<String, String> get _params => GoRouterState.of(context).uri.queryParameters;
  String get _filter => _filters.contains(_params['filter']) ? _params['filter']! : 'all';
  String get _q => _params['q'] ?? '';
  int get _page => readPage(_params['page']);

  Future<RatingPage> _fetch() => ref.read(apiProvider).ratings.list(filter: _filter, q: _q, page: _page);

  void _onLoad() {
    if (mounted) setState(() {});
    final d = _list.data;
    if (d != null && d.page != _page && mounted) setQuery(context, {'page': d.page <= 1 ? null : '${d.page}'});
  }

  @override
  void initState() {
    super.initState();
    _auto.touched();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = '$_filter|$_q|$_page';
    if (key != _key) {
      _key = key;
      _list.fetch = _fetch;
      _list.load();
      _auto.touched();
    }
  }

  @override
  void dispose() {
    _auto.dispose();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _resolve(RatingRow r) async {
    setState(() => _busy.add(r.id));
    try {
      await ref.read(apiProvider).ratings.resolve(r.id);
      toast('Şikâyet çözüldü olarak işaretlendi.');
      await Future.wait([_list.load(silent: true), ref.read(dashboardProvider.notifier).reload()]);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _list.data;
    final summary = data?.summary ?? const <String, dynamic>{};
    final filter = _filter;
    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListState(
        loading: _list.loading,
        hasData: data != null,
        count: data?.items.length ?? 0,
        error: _list.error,
        stale: _list.stale,
        onRetry: () => _list.load(),
        query: _q,
        empty: filter == 'all' ? 'Henüz puan gelmedi. İş teslim edildikçe müşterilerinize puan linki gider.' : 'Bu listede kayıt yok.',
        searchEmpty: 'Aramaya uyan puan yok.',
      ),
      if (data == null && _list.loading) const CardSkeleton(count: 2),
      if (data != null) ...data.items.map(_card),
      if (data != null)
        Pager(page: data.page, total: data.total, noun: 'puan', nounFrom: 'puandan', onPage: (p) {
          setQuery(context, {'page': p <= 1 ? null : '$p'});
          _scroll.jumpTo(0);
        }),
    ]);
    return OpsPage(
      title: 'Yorumlar',
      subtitle: 'Müşterileriniz işinizi nasıl puanladı',
      search: 'Ad, telefon, fiş no veya şikâyet ara',
      controller: _scroll,
      onRefresh: () => _list.load(silent: true),
      children: [
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedTabs<String>(
            items: [
              ('all', 'Tümü', summary.iOrNull('total')),
              ('unresolved', 'Bekleyen şikâyetler', summary.iOrNull('openCrises')),
              ('shield', '1–4 yıldız', summary.iOrNull('shieldCount')),
              ('google', '5 yıldız', summary.iOrNull('googleCount')),
              ('resolved', 'Çözülenler', summary.iOrNull('resolvedCount')),
            ],
            value: filter,
            onChanged: (f) => setQuery(context, {'filter': f == 'all' ? null : f, 'page': null}),
          ),
          TextButton(onPressed: () => context.push('/ops/puan-onizleme'), child: const Text('Müşterinin gördüğü ekranı aç')),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth > 860) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: list),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: _Summary(summary: summary)),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (data != null) _Summary(summary: summary, compact: true), list]);
        }),
      ],
    );
  }

  Widget _card(RatingRow r) {
    final happy = r.route == 'google';
    final open = !happy && !r.resolved;
    final filled = r.stars.round().clamp(0, 5);
    final service = serviceOf(r.serviceType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: open ? const Color(0xFFE9B8B2) : C.line),
        boxShadow: Shadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Monogram(r.customerName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text('${'★' * filled}${'☆' * (5 - filled)}', style: const TextStyle(color: C.gold, fontSize: 15, letterSpacing: 1)),
            ]),
          ),
          if (open) const Pill('Aranmayı bekliyor', tone: 'bad'),
          if (r.resolved) const Pill('Çözüldü', tone: 'ok'),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [AppIcon(service.icon, size: 15, color: C.muted), const SizedBox(width: 5), Text(service.title, style: const TextStyle(fontSize: 13, color: C.inkSoft))]),
          Text('#${r.reference}', style: const TextStyle(fontSize: 13, color: C.muted, fontFeatures: tabular)),
          InkWell(onTap: () => callPhone(r.phone), child: Text(displayPhone(r.phone), style: const TextStyle(fontSize: 13, fontFeatures: tabular))),
          Text(formatStamp(r.submittedAt), style: const TextStyle(fontSize: 13, color: C.muted)),
        ]),
        if (r.reasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final code in r.reasons) Pill(reasonLabel(code), tone: 'wait')]),
        ],
        if ((r.note ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.lineStrong, width: 3))),
            child: Text('“${r.note!.trim()}”', style: const TextStyle(fontStyle: FontStyle.italic, color: C.inkSoft, height: 1.4)),
          ),
        ],
        if (open) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(onPressed: () => openWhatsapp(r.phone), icon: const AppIcon('chat', size: 16), label: const Text("WhatsApp'tan Yaz")),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy.contains(r.id) ? null : () => _resolve(r), child: const Text('Çözüldü')),
          ]),
        ],
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, this.compact = false});
  final Json summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rawAvg = summary.n('average');
    final avg = rawAvg != null && rawAvg > 0 ? rawAvg : null;
    final starCounts = summary.nums('starCounts');
    int countOf(int star) => starCounts.length >= star ? starCounts[star - 1].toInt() : 0;

    final counts = {for (var s = 5; s >= 1; s--) s: countOf(s)};
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(avg == null ? '—' : decimalTr(avg), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -1)),
      Text('${'★' * (avg?.round() ?? 0)}${'☆' * (5 - (avg?.round() ?? 0))}', style: const TextStyle(color: C.gold, fontSize: 16)),
      Text('${summary.i('total')} değerlendirme', style: const TextStyle(color: C.muted, fontSize: 13)),
    ]);
    final bars = Column(children: [
      for (final e in counts.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${e.key}★', style: const TextStyle(fontSize: 12.5, color: C.inkSoft))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : e.value / max,
                  minHeight: 7,
                  backgroundColor: C.chip,
                  valueColor: AlwaysStoppedAnimation(e.key >= 4 ? C.ok : (e.key == 3 ? C.gold : C.bad)),
                ),
              ),
            ),
            SizedBox(width: 34, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontFeatures: tabular))),
          ]),
        ),
    ]);
    final stats = Column(children: [
      for (final (k, v) in [('Bekleyen şikâyet', summary.i('openCrises')), ('Çözülen şikâyet', summary.i('resolvedCount')), ('5 yıldız veren', summary.i('googleCount'))])
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [Expanded(child: Text(k, style: const TextStyle(color: C.inkSoft, fontSize: 13))), Text('$v', style: const TextStyle(fontWeight: FontWeight.w700))]),
        ),
    ]);
    if (compact) {
      return Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [head, const SizedBox(width: 18), Expanded(child: bars)]),
      );
    }
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, const SizedBox(height: 14), bars, const Divider(), stats]));
  }
}
