import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../customers/customer_drawer.dart';
import '../shell/dashboard.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';
import 'intake_form.dart';
import 'order_card.dart';
import 'pending_moves.dart';

final intakeProvider = Provider<IntakeController>((ref) {
  final c = IntakeController();
  ref.onDispose(c.dispose);
  return c;
});

const _tabs = ['open', 'collected', 'washing', 'delivered'];

class DeskPage extends ConsumerStatefulWidget {
  const DeskPage({super.key});
  @override
  ConsumerState<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends ConsumerState<DeskPage> {
  late final Loader<OrderPage> _orders = Loader(_fetch)..addListener(_onLoad);
  late final AutoRefresh _auto = AutoRefresh(const Duration(seconds: 45), () => _refreshAll());
  final _scroll = ScrollController();
  String _key = '';
  late final PendingMoves _pending;

  String get _tab {
    final t = GoRouterState.of(context).uri.queryParameters['tab'];
    return _tabs.contains(t) ? t! : 'open';
  }

  String get _q => GoRouterState.of(context).uri.queryParameters['q'] ?? '';
  int get _page => readPage(GoRouterState.of(context).uri.queryParameters['page']);

  Future<OrderPage> _fetch() => ref.read(apiProvider).orders.list(tab: _tab, q: _q, page: _page);

  void _onLoad() {
    if (mounted) setState(() {});
    final d = _orders.data;
    if (d != null && d.page != _page && mounted) setQuery(context, {'page': d.page <= 1 ? null : '${d.page}'});
  }

  String _handledUri = '';

  @override
  void initState() {
    super.initState();
    _pending = ref.read(pendingMovesProvider);
    _auto.touched();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final params = uri.queryParameters;
    final fresh = uri.toString() != _handledUri;
    _handledUri = uri.toString();
    final key = '$_tab|$_q|$_page';
    if (key != _key) {
      if (_key.isNotEmpty) _pending.flushAll();
      _key = key;
      _orders.fetch = _fetch;
      _orders.load();
    }
    if (fresh && params['new'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setQuery(context, {'new': null});
        _openSheet();
      });
    }
    final fill = params['fill'];
    if (fresh && fill != null && fill.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setQuery(context, {'fill': null});
        try {
          final card = await ref.read(apiProvider).customers.card(fill);
          ref.read(intakeProvider).fill(card);
          if (mounted) _openSheet();
        } catch (_) {
          toast('Müşteri kartı açılamadı; boş fiş açabilirsiniz.', tone: ToastTone.bad);
        }
      });
    }
    if (fresh && params['notice'] == 'forbidden') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setQuery(context, {'notice': null});
        toast('Bu sayfaya yalnızca yöneticiler girebilir.', tone: ToastTone.bad);
      });
    }
  }

  @override
  void dispose() {
    _pending.flushAll();
    _auto.dispose();
    _orders.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    _auto.touched();
    await Future.wait([
      _orders.load(silent: true),
      ref.read(dashboardProvider.notifier).reload(),
      () async {
        try {
          ref.read(intakeProvider).setSuggested(await ref.read(apiProvider).orders.suggestedReference());
        } catch (_) {}
      }(),
    ]);
  }

  void _openSheet() => openIntakeSheet(context, ref.read(intakeProvider), _refreshAll);

  void _openCustomer(String id) => openCustomerDrawer(context, customerId: id, onChanged: () => _orders.load(silent: true), onFill: (card) {
        ref.read(intakeProvider).fill(card);
        _openSheet();
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider.select((s) => s.me));
    final dash = ref.watch(dashboardProvider);
    final data = _orders.data;
    final tab = _tab;
    final q = _q;
    Widget card(DeskOrder o) => OrderCard(key: ValueKey(o.id), order: o, onChanged: _refreshAll, onOpenCustomer: _openCustomer);
    return OpsPage(
      search: 'Ad, telefon veya fiş no ara',
      controller: _scroll,
      onRefresh: _refreshAll,
      lead: _Greeting(name: me?.firstName ?? ''),
      children: [
        _DayLine(kpis: dash?.kpis ?? const {}),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedTabs<String>(
            items: [
              ('open', 'Açık İşler', (dash?.tabs['open'] as num?)?.toInt()),
              ('collected', 'Teslim Alındı', (dash?.tabs['collected'] as num?)?.toInt()),
              ('washing', 'Yıkamada', (dash?.tabs['washing'] as num?)?.toInt()),
              ('delivered', 'Teslim Edilenler', (dash?.tabs['delivered'] as num?)?.toInt()),
            ],
            value: tab,
            onChanged: (t) => setQuery(context, {'tab': t == 'open' ? null : t, 'page': null}),
          ),
          _Todos(me: me, dash: dash),
        ]),
        const SizedBox(height: 14),
        if (tab == 'delivered')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text(q.isNotEmpty ? 'Arama bütün teslimatlarda yapıldı.' : 'Son 7 günün teslimatları, teslim gününe göre.',
                    style: const TextStyle(color: C.muted, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => context.go(withQuery('/ops/arsiv', {if (q.isNotEmpty) 'q': q})),
                child: const Text("Daha eskileri Arşiv'de →"),
              ),
            ]),
          ),
        ListState(
          loading: _orders.loading,
          hasData: data != null,
          count: data?.items.length ?? 0,
          error: _orders.error,
          stale: _orders.stale,
          onRetry: () => _orders.load(),
          query: q,
          empty: tab == 'delivered' ? 'Son 7 günde teslim edilen iş yok.' : 'Açık iş yok. Yeni bir iş için “Yeni fiş” düğmesine basın.',
          searchEmpty: 'Aramaya uyan fiş yok.',
        ),
        if (data == null && _orders.loading) const CardSkeleton(),
        if (data != null)
          if (tab == 'delivered') DayGroups(items: data.items, days: data.days, itemBuilder: card) else ...data.items.map(card),
        if (data != null)
          Pager(
            page: data.page,
            total: data.total,
            onPage: (p) {
              setQuery(context, {'page': p <= 1 ? null : '$p'});
              _scroll.jumpTo(0);
            },
          ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('${greeting(now)}${name.isEmpty ? '' : ', $name'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.4)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.line)),
        child: Text(formatToday(now), style: const TextStyle(fontSize: 12.5, color: C.inkSoft, fontWeight: FontWeight.w500)),
      ),
    ]);
  }
}

class _DayLine extends StatelessWidget {
  const _DayLine({required this.kpis});
  final Map<String, dynamic> kpis;

  @override
  Widget build(BuildContext context) {
    final revenue = kpis['revenueToday'];
    final cards = [
      _Kpi('Açık işler', '${kpis['activeOrders'] ?? '—'}', 'Aktif işlem gören fişler', 'desk'),
      _Kpi('Yıkamada', '${kpis['washingOrders'] ?? '—'}', 'Atölyede devam eden', 'drops'),
      _Kpi('Bugün teslim', '${kpis['deliveredToday'] ?? '—'}', 'Bugün teslim edilen', 'check'),
      if (revenue is num) _Kpi('Bugünkü ciro', money(revenue)!, 'Bugün teslim edilen işlerden', 'till', dark: true),
    ];
    return LayoutBuilder(builder: (context, box) {
      final perRow = box.maxWidth > 700 ? cards.length : 2;
      final w = (box.maxWidth - (perRow - 1) * 10) / perRow;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in cards) SizedBox(width: w, child: c)]);
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.sub, this.icon, {this.dark = false});
  final String label;
  final String value;
  final String sub;
  final String icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => Panel(
        dark: dark,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(trUpper(label),
                  style: TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w600, color: dark ? C.sideInk : C.muted)),
            ),
            AppIcon(icon, size: 17, color: dark ? C.gold : C.stone),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: dark ? Colors.white : C.ink, fontFeatures: tabular, letterSpacing: -.5)),
          ),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: dark ? C.sideInk : C.muted)),
        ]),
      );
}

class _Todos extends StatelessWidget {
  const _Todos({required this.me, required this.dash});
  final Me? me;
  final Dashboard? dash;

  @override
  Widget build(BuildContext context) {
    final tenant = me?.tenant;
    final manager = me?.isManager ?? false;
    if (tenant == null) return const SizedBox.shrink();
    final todos = <(String, String, String?)>[];
    if (!tenant.whatsappBound) {
      todos.add(('bad', 'WhatsApp bağlı değil', manager ? '/ops/ayarlar' : null));
    } else if ((dash?.stuck ?? 0) > 0) {
      todos.add(('bad', '${dash!.stuck} mesaj ulaşmadı', manager ? '/ops/ayarlar' : null));
    }
    if ((dash?.overdue ?? 0) > 0) todos.add(('bad', '${dash!.overdue} iş teslim sözünü aştı', manager ? '/ops/analiz?focus=geciken' : '/ops/servis'));
    if ((dash?.openCrises ?? 0) > 0) todos.add(('warn', '${dash!.openCrises} düşük puan bekliyor', '/ops/degerlendirmeler?filter=unresolved'));
    final done = [tenant.whatsappBound, tenant.setupGoogleReview, tenant.setupIban].where((x) => x).length;
    if (manager && done < 3) todos.add(('plain', 'Kurulumu tamamlayın ($done/3)', '/ops/ayarlar'));
    if (todos.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (tone, text, path) in todos)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: C.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: path == null ? null : () => context.go(path),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tone == 'warn' ? C.gold : C.line),
                    boxShadow: tone == 'warn' ? const [BoxShadow(color: Color(0x33C5A059), blurRadius: 10, offset: Offset(0, 2))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: tone == 'bad' ? C.bad : (tone == 'warn' ? C.gold : C.stone))),
                    const SizedBox(width: 8),
                    Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
