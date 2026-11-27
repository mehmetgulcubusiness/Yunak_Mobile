import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_events.dart';
import '../../core/api/json.dart';
import '../../core/config.dart';
import '../../core/constants/labels.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../auth/gate.dart';
import '../widgets/common.dart';
import 'dashboard.dart';

class NavItem {
  const NavItem(this.section, this.label, this.path, this.icon, {this.manager = false});
  final String section;
  final String label;
  final String path;
  final String icon;
  final bool manager;
}

const navItems = [
  NavItem('desk', 'İşler', '/ops', 'desk'),
  NavItem('archive', 'Arşiv', '/ops/arsiv', 'archive'),
  NavItem('customers', 'Müşteriler', '/ops/musteriler', 'user'),
  NavItem('ratings', 'Yorumlar', '/ops/degerlendirmeler', 'star'),
  NavItem('route', 'Servis listesi', '/ops/servis', 'truck'),
  NavItem('cash', 'Kasa', '/ops/kasa', 'till', manager: true),
  NavItem('analytics', 'Analiz', '/ops/analiz', 'chart', manager: true),
  NavItem('settings', 'Ayarlar', '/ops/ayarlar', 'gear', manager: true),
];

String sectionOf(String path) {
  for (final item in navItems.reversed) {
    if (item.path != '/ops' && path.startsWith(item.path)) return item.section;
  }
  if (path.startsWith('/ops/sifre')) return 'password';
  if (path.startsWith('/ops/cihazlar')) return 'devices';
  if (path.startsWith('/ops/hesap')) return 'account';
  return 'desk';
}

/// Bütün /ops sayfalarının kabuğu: geniş ekranda yan menü, dar ekranda çekmece + alt sekme çubuğu.
class OpsShell extends ConsumerStatefulWidget {
  const OpsShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<OpsShell> createState() => _OpsShellState();
}

class _OpsShellState extends ConsumerState<OpsShell> with WidgetsBindingObserver {
  Timer? _idle;
  DateTime _lastTouch = DateTime.now();
  StreamSubscription<ApiEvent>? _events;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdle();
    _events = ApiEvents.stream.listen((e) {
      if (!mounted) return;
      if (e is Offline && !_offline) setState(() => _offline = true);
      if (e is Online && _offline) {
        setState(() => _offline = false);
        ref.read(dashboardProvider.notifier).reload();
      }
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resetIdle() {
    _lastTouch = DateTime.now();
    _idle?.cancel();
    _idle = Timer(AppConfig.idleTimeout, _idleOut);
  }

  void _idleOut() {
    if (!mounted) return;
    ref.read(sessionProvider.notifier).signOut(notice: LoginNotice.idle);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastTouch) >= AppConfig.idleTimeout) {
        _idleOut();
      } else {
        ref.read(dashboardProvider.notifier).reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider.select((s) => s.me));
    final dash = ref.watch(dashboardProvider);
    final section = sectionOf(widget.location);
    final crises = dash?.openCrises ?? me?.openCrises ?? 0;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdle(),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > Bp.wide;
        final body = Column(children: [
          if (_offline) const _NetworkBanner(),
          Expanded(child: _offline ? MediaQuery.removePadding(context: context, removeTop: true, child: widget.child) : widget.child),
        ]);
        if (wide) {
          return Scaffold(
            key: OpsShell.scaffoldKey,
            body: Row(children: [
              SizedBox(width: 240, child: SideNav(me: me, dash: dash, section: section)),
              Expanded(child: body),
            ]),
          );
        }
        return Scaffold(
          key: OpsShell.scaffoldKey,
          drawer: Drawer(width: 280, backgroundColor: C.side, child: SideNav(me: me, dash: dash, section: section, inDrawer: true)),
          body: body,
          bottomNavigationBar: me?.tenant == null ? null : _TabBar(section: section, crises: crises),
        );
      }),
    );
  }
}

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: C.bad,
        padding: EdgeInsets.fromLTRB(16, 8 + MediaQuery.paddingOf(context).top, 16, 8),
        child: const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Bağlantı yok. ', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: 'Sunucuya ulaşılamıyor. Girdiğiniz bilgiler ekranda duruyor; bağlantı gelince yeniden gönderin.'),
          ]),
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
}

class SideNav extends ConsumerWidget {
  const SideNav({super.key, required this.me, required this.dash, required this.section, this.inDrawer = false});
  final Me? me;
  final Dashboard? dash;
  final String section;
  final bool inDrawer;

  void _go(BuildContext context, String path) {
    if (inDrawer) Navigator.of(context).pop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = me?.isManager ?? false;
    final tenant = me?.tenant;
    final crises = dash?.openCrises ?? me?.openCrises ?? 0;
    final overdue = dash?.overdue ?? 0;
    final items = navItems.where((i) => !i.manager || manager);
    return Container(
      color: C.side,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => _go(context, '/ops'),
            child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 18), child: Brand(dark: true, name: tenant?.name ?? 'Yunak Platform')),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
              for (final item in items)
                _NavTile(
                  item: item,
                  selected: item.section == section,
                  badge: item.section == 'ratings' ? crises : (item.section == 'analytics' ? overdue : 0),
                  onTap: () => _go(context, item.path),
                ),
            ]),
          ),
          if (tenant != null) _WhatsappStatus(tenant: tenant, dash: dash, manager: manager, onTap: manager ? () => _go(context, '/ops/ayarlar') : null),
          const Divider(color: C.side2, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Monogram(me?.userName ?? '', size: 34, dark: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me?.userName ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(roleLabels[me?.role] ?? '', style: const TextStyle(color: C.sideInk, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Wrap(children: [
              _link('Şifremi değiştir', () => _go(context, '/ops/sifre')),
              if (!ref.read(apiClientProvider).cookieMode) _link('Cihazlarım', () => _go(context, '/ops/cihazlar')),
              _link('Çıkış', () async {
                if (inDrawer) Navigator.of(context).pop();
                await ref.read(sessionProvider.notifier).signOut();
              }),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: C.sideInk, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 34)),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.badge, required this.onTap});
  final NavItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? C.side2 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                AppIcon(item.icon, size: 18, color: selected ? Colors.white : C.sideInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      style: TextStyle(color: selected ? Colors.white : C.sideInk, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                ),
                if (badge > 0) Ping(badge),
              ]),
            ),
          ),
        ),
      );
}

class _WhatsappStatus extends StatelessWidget {
  const _WhatsappStatus({required this.tenant, required this.dash, required this.manager, this.onTap});
  final Tenant tenant;
  final Dashboard? dash;
  final bool manager;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stuck = dash?.stuck ?? 0;
    final (led, title, sub) = !tenant.whatsappBound
        ? (C.stone, 'WhatsApp bağlı değil', manager ? 'Bağlamak için dokunun' : 'Yöneticiniz bağlayabilir')
        : stuck > 0
            ? (const Color(0xFFEF4444), 'Mesajlarda sorun var', '$stuck mesaj ulaşmadı')
            : (const Color(0xFF22C55E), 'WhatsApp bağlı', '${dash?.queue.i('sent') ?? 0} mesaj iletildi');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Material(
        color: C.side2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: led, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(sub, style: const TextStyle(color: C.sideInk, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.section, required this.crises});
  final String section;
  final int crises;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, String icon, bool selected, VoidCallback onTap, {int badge = 0, bool dot = false}) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  AppIcon(icon, size: 21, color: selected ? C.ink : C.muted),
                  if (badge > 0) Positioned(right: -12, top: -6, child: Ping(badge)),
                  if (dot) Positioned(right: -3, top: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.bad, shape: BoxShape.circle))),
                ]),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontSize: 11, color: selected ? C.ink : C.muted, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              ]),
            ),
          ),
        );
    return Container(
      decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: SizedBox(height: 60, child: Row(children: [
            tab('İşler', 'desk', section == 'desk', () => context.go('/ops')),
            tab('Müşteriler', 'user', section == 'customers', () => context.go('/ops/musteriler')),
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Yeni fiş',
                  child: GestureDetector(
                    onTap: () => context.go('/ops?new=1'),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.action,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x8009090B), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -6)],
                      ),
                      child: const AppIcon('plus', size: 26, color: C.gold),
                    ),
                  ),
                ),
              ),
            ),
            tab('Yorumlar', 'star', section == 'ratings', () => context.go('/ops/degerlendirmeler'), badge: crises),
            tab('Menü', 'menu', false, () => OpsShell.scaffoldKey.currentState?.openDrawer(), dot: crises > 0),
          ])),
        ),
      ),
    );
  }
}

/// Sayfa çerçevesi: başlık (veya selam), arama, eylemler, kaydırılabilir içerik.
class OpsPage extends StatelessWidget {
  const OpsPage({
    super.key,
    this.title,
    this.subtitle,
    this.lead,
    this.actions = const [],
    this.search,
    required this.children,
    this.onRefresh,
    this.controller,
    this.maxWidth,
  });

  final String? title;
  final String? subtitle;
  final Widget? lead;
  final List<Widget> actions;
  final String? search;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 900 - 240 && MediaQuery.sizeOf(context).width > Bp.wide;
      final pad = MediaQuery.sizeOf(context).width > Bp.wide ? 32.0 : (box.maxWidth > Bp.phone ? 18.0 : 14.0);
      final top = MediaQuery.paddingOf(context).top;
      final bar = Padding(
        padding: EdgeInsets.fromLTRB(wide ? pad : 4, top + 8, pad, 6),
        child: Row(children: [
          if (!wide)
            IconButton(
              tooltip: 'Menü',
              onPressed: () => OpsShell.scaffoldKey.currentState?.openDrawer(),
              icon: const AppIcon('menu', size: 22),
            ),
          if (search != null) Expanded(child: Finder(placeholder: search!)) else const Spacer(),
          if (wide) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.go('/ops?new=1'),
              icon: const AppIcon('plus', size: 18, color: C.gold),
              label: const Text('Yeni Fiş Oluştur'),
            ),
          ],
        ]),
      );
      final heading = (title != null || lead != null || actions.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 6),
              child: Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                lead ??
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.4)),
                      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: const TextStyle(color: C.muted, fontSize: 14))),
                    ]),
                if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
              ]),
            )
          : const SizedBox.shrink();
      Widget content = ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, 4, pad, MediaQuery.sizeOf(context).width > Bp.wide ? 40 : 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth ?? 1280),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, ...children]),
            ),
          ),
        ],
      );
      if (onRefresh != null) content = RefreshIndicator(color: C.ink, onRefresh: onRefresh!, child: content);
      return Column(children: [bar, Expanded(child: content)]);
    });
  }
}

/// Üst bar araması: URL'deki `q`. 350 ms sonra (Enter'da hemen) uygulanır.
class Finder extends StatefulWidget {
  const Finder({super.key, required this.placeholder});
  final String placeholder;
  @override
  State<Finder> createState() => _FinderState();
}

class _FinderState extends State<Finder> {
  final _c = TextEditingController();
  Timer? _debounce;
  String _applied = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = GoRouterState.of(context).uri.queryParameters['q'] ?? '';
    if (q != _applied) {
      _applied = q;
      if (_c.text.trim() != q) _c.text = q;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _apply(String raw) {
    _debounce?.cancel();
    var v = raw.trim();
    if (v.length > 80) v = v.substring(0, 80);
    if (v == _applied) return;
    _applied = v;
    final uri = GoRouterState.of(context).uri;
    final params = Map<String, String>.from(uri.queryParameters)..remove('page');
    if (v.isEmpty) {
      params.remove('q');
    } else {
      params['q'] = v;
    }
    context.go(withQuery(uri.path, params));
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        maxLength: 80,
        onChanged: (v) {
          setState(() {});
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () => _apply(v));
        },
        onSubmitted: _apply,
        decoration: InputDecoration(
          counterText: '',
          hintText: widget.placeholder,
          prefixIcon: const Padding(padding: EdgeInsets.all(12), child: AppIcon('search', size: 18, color: C.muted)),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.close, size: 18, color: C.muted),
                  onPressed: () {
                    _c.clear();
                    setState(() {});
                    _apply('');
                  },
                ),
        ),
      );
}

/// URL'deki query parametrelerini değiştirir (null → siler).
void setQuery(BuildContext context, Map<String, String?> changes) {
  final uri = GoRouterState.of(context).uri;
  final params = Map<String, String>.from(uri.queryParameters);
  changes.forEach((k, v) {
    if (v == null || v.isEmpty) {
      params.remove(k);
    } else {
      params[k] = v;
    }
  });
  context.go(withQuery(uri.path, params));
}

int readPage(String? raw) {
  final n = int.tryParse(raw ?? '');
  return n == null || n < 1 ? 1 : n;
}

String withQuery(String path, Map<String, String> params) =>
    params.isEmpty ? path : Uri(path: path, queryParameters: params).toString();
