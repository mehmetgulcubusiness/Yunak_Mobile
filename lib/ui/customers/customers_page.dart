import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/loader.dart';
import 'customer_drawer.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});
  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  late final Loader<Paged<CustomerRow>> _list = Loader(_fetch)..addListener(_onLoad);
  final _scroll = ScrollController();
  String _key = '';

  String get _q => GoRouterState.of(context).uri.queryParameters['q'] ?? '';
  int get _page => readPage(GoRouterState.of(context).uri.queryParameters['page']);

  Future<Paged<CustomerRow>> _fetch() => ref.read(apiProvider).customers.list(q: _q, page: _page);

  void _onLoad() {
    if (mounted) setState(() {});
    final d = _list.data;
    if (d != null && d.page != _page && mounted) setQuery(context, {'page': d.page <= 1 ? null : '${d.page}'});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = '$_q|$_page';
    if (key != _key) {
      _key = key;
      _list.fetch = _fetch;
      _list.load();
    }
  }

  @override
  void dispose() {
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(String id) => openCustomerDrawer(context,
      customerId: id, onChanged: () => _list.load(silent: true), onFill: (card) => context.go('/ops?fill=${Uri.encodeComponent(card.id)}'));

  @override
  Widget build(BuildContext context) {
    final data = _list.data;
    return OpsPage(
      title: 'Müşteriler',
      subtitle: data == null ? null : '${data.total} kayıtlı müşteri',
      search: 'Ad, telefon veya adres ara',
      controller: _scroll,
      onRefresh: () => _list.load(silent: true),
      children: [
        ListState(
          loading: _list.loading,
          hasData: data != null,
          count: data?.items.length ?? 0,
          error: _list.error,
          stale: _list.stale,
          onRetry: () => _list.load(),
          query: _q,
          empty: 'Henüz müşteri yok. İlk fişi açtığınızda müşteri buraya eklenir.',
          searchEmpty: 'Aramaya uyan müşteri yok.',
        ),
        if (data == null && _list.loading) const CardSkeleton(count: 4),
        if (data != null && data.items.isNotEmpty)
          LayoutBuilder(builder: (context, box) => box.maxWidth > Bp.phone ? _table(data.items) : Column(children: data.items.map(_card).toList())),
        if (data != null)
          Pager(page: data.page, total: data.total, noun: 'müşteri', nounFrom: 'müşteriden', onPage: (p) {
            setQuery(context, {'page': p <= 1 ? null : '$p'});
            _scroll.jumpTo(0);
          }),
      ],
    );
  }

  Widget _name(CustomerRow r) => InkWell(
        onTap: () => _open(r.id),
        child: Row(children: [
          Monogram(r.name, size: 32),
          const SizedBox(width: 10),
          Flexible(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (r.optedOut) const Padding(padding: EdgeInsets.only(left: 8), child: Pill('Mesaj kapalı', tone: 'muted')),
        ]),
      );

  Widget _table(List<CustomerRow> rows) {
    const head = TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600, letterSpacing: .4);
    Widget cell(Widget child, int flex, {bool end = false}) => Expanded(flex: flex, child: Align(alignment: end ? Alignment.centerRight : Alignment.centerLeft, child: child));
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(children: [
            cell(const Text('AD SOYAD', style: head), 28),
            cell(const Text('TELEFON', style: head), 16),
            cell(const Text('ADRES', style: head), 26),
            cell(const Text('SİPARİŞ', style: head), 9, end: true),
            cell(const Text('TOPLAM', style: head), 12, end: true),
            const SizedBox(width: 16),
            cell(const Text('SON SİPARİŞ', style: head), 13),
          ]),
        ),
        for (final r in rows) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              cell(_name(r), 28),
              cell(InkWell(onTap: () => callPhone(r.phone), child: Text(displayPhone(r.phone), style: const TextStyle(fontFeatures: tabular))), 16),
              cell(Text(r.address ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.inkSoft, fontSize: 13)), 26),
              cell(Text('${r.orderCount}', style: const TextStyle(fontFeatures: tabular)), 9, end: true),
              cell(Text(money(r.totalTry) ?? '0 ₺', style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabular)), 12, end: true),
              const SizedBox(width: 16),
              cell(Text(r.lastOrderAt == null ? '—' : formatDay(r.lastOrderAt), style: const TextStyle(color: C.inkSoft, fontSize: 13)), 13),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _card(CustomerRow r) {
    Widget line(String k, Widget v) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [SizedBox(width: 92, child: Text(k, style: const TextStyle(color: C.muted, fontSize: 13))), Expanded(child: v)]),
        );
    return Panel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _name(r),
        const SizedBox(height: 4),
        line('Telefon', InkWell(onTap: () => callPhone(r.phone), child: Text(displayPhone(r.phone), style: const TextStyle(fontFeatures: tabular)))),
        line('Adres', Text(r.address ?? '—', style: const TextStyle(fontSize: 13.5))),
        line('Sipariş', Text('${r.orderCount}')),
        line('Toplam', Text(money(r.totalTry) ?? '0 ₺', style: const TextStyle(fontWeight: FontWeight.w600))),
        line('Son sipariş', Text(r.lastOrderAt == null ? '—' : formatDay(r.lastOrderAt))),
      ]),
    );
  }
}
