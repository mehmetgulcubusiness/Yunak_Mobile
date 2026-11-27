import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/json.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../customers/customer_drawer.dart';
import '../shell/dashboard.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';
import 'order_card.dart';
import 'pending_moves.dart';

class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});
  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  late final Loader<OrderPage> _orders = Loader(_fetch)..addListener(_onLoad);
  final _scroll = ScrollController();
  String _key = '';
  late final PendingMoves _pending;

  @override
  void initState() {
    super.initState();
    _pending = ref.read(pendingMovesProvider);
  }

  Map<String, String> get _params => GoRouterState.of(context).uri.queryParameters;
  String get _q => _params['q'] ?? '';
  String? get _month => RegExp(r'^\d{4}-\d{2}$').hasMatch(_params['month'] ?? '') ? _params['month'] : null;
  int get _page => readPage(_params['page']);

  Future<OrderPage> _fetch() => ref.read(apiProvider).orders.list(tab: 'archive', q: _q, page: _page, month: _month);

  void _onLoad() {
    if (mounted) setState(() {});
    final d = _orders.data;
    if (d != null && d.page != _page && mounted) setQuery(context, {'page': d.page <= 1 ? null : '${d.page}'});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = '$_q|$_month|$_page';
    if (key != _key) {
      if (_key.isNotEmpty) _pending.flushAll();
      _key = key;
      _orders.fetch = _fetch;
      _orders.load();
    }
  }

  @override
  void dispose() {
    _pending.flushAll();
    _orders.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() => Future.wait([_orders.load(silent: true), ref.read(dashboardProvider.notifier).reload()]);

  @override
  Widget build(BuildContext context) {
    final data = _orders.data;
    final month = _month;
    final dash = ref.watch(dashboardProvider);
    return OpsPage(
      title: 'Arşiv',
      subtitle: 'Teslim edilen bütün işler, teslim gününe göre',
      search: 'Arşivde ad, telefon veya fiş no ara',
      controller: _scroll,
      onRefresh: _reload,
      children: [
        if (data != null && data.months.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SegmentedTabs<String>(
              items: [
                ('', 'Tümü', (dash?.tabs['archive'] as num?)?.toInt()),
                for (final m in data.months) (m.str('month'), monthLabel(m.str('month')), m.i('count')),
              ],
              value: month ?? '',
              onChanged: (m) => setQuery(context, {'month': m, 'page': null}),
            ),
          ),
        ListState(
          loading: _orders.loading,
          hasData: data != null,
          count: data?.items.length ?? 0,
          error: _orders.error,
          stale: _orders.stale,
          onRetry: () => _orders.load(),
          query: _q,
          empty: month != null ? 'Bu ayda teslim edilen iş yok.' : 'Henüz teslim edilen iş yok.',
          searchEmpty: 'Aramaya uyan teslimat yok.',
        ),
        if (data == null && _orders.loading) const CardSkeleton(),
        if (data != null)
          DayGroups(
            items: data.items,
            days: data.days,
            itemBuilder: (o) => OrderCard(
              key: ValueKey(o.id),
              order: o,
              onChanged: _reload,
              onOpenCustomer: (id) => openCustomerDrawer(context,
                  customerId: id, onChanged: () => _orders.load(silent: true), onFill: (card) => context.go('/ops?fill=${Uri.encodeComponent(card.id)}')),
            ),
          ),
        if (data != null)
          Pager(page: data.page, total: data.total, onPage: (p) {
            setQuery(context, {'page': p <= 1 ? null : '$p'});
            _scroll.jumpTo(0);
          }),
      ],
    );
  }
}
