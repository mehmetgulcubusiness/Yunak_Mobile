import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session.dart';
import '../ui/account/account_pages.dart';
import '../ui/auth/login_page.dart';
import '../ui/auth/register_page.dart';
import '../ui/auth/status_pages.dart';
import '../ui/customers/customers_page.dart';
import '../ui/desk/archive_page.dart';
import '../ui/desk/desk_page.dart';
import '../ui/manager/analytics_page.dart';
import '../ui/manager/cash_page.dart';
import '../ui/manager/settings_page.dart';
import '../ui/ratings/rating_preview_page.dart';
import '../ui/ratings/ratings_page.dart';
import '../ui/route/route_page.dart';
import '../ui/shell/ops_shell.dart';

/// Oturum değiştikçe router'ı yeniden yönlendirmeye zorlar.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (prev, next) {
      if (prev?.status != next.status || prev?.me?.role != next.me?.role) notifyListeners();
    });
  }
}

const _managerOnly = ['/ops/kasa', '/ops/analiz', '/ops/ayarlar'];

NoTransitionPage<void> _page(GoRouterState s, Widget child) => NoTransitionPage(key: s.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/ops',
    refreshListenable: refresh,
    errorBuilder: (_, _) => const NotFoundPage(),
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final path = state.uri.path;
      final atGate = path == '/login' || path == '/register';
      switch (s.status) {
        case SessionStatus.loading:
          return path == '/splash' ? null : '/splash';
        case SessionStatus.outdated:
          return path == '/update' ? null : '/update';
        case SessionStatus.blocked:
          return path == '/blocked' ? null : '/blocked';
        case SessionStatus.anonymous:
          return atGate ? null : '/login';
        case SessionStatus.ready:
          if (atGate || path == '/splash' || path == '/blocked' || path == '/update' || path == '/') {
            final from = s.from;
            return from != null && from.startsWith('/ops') ? from : '/ops';
          }
          if (_managerOnly.any(path.startsWith) && !(s.me?.isManager ?? false)) return '/ops?notice=forbidden';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/ops'),
      GoRoute(path: '/splash', pageBuilder: (_, s) => _page(s, const SplashPage())),
      GoRoute(path: '/login', pageBuilder: (_, s) => _page(s, const LoginPage())),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/blocked', pageBuilder: (_, s) => _page(s, const BlockedPage())),
      GoRoute(path: '/update', pageBuilder: (_, s) => _page(s, const UpdatePage())),
      GoRoute(path: '/ops/puan-onizleme', builder: (_, _) => const RatingPreviewPage()),
      ShellRoute(
        builder: (context, state, child) => OpsShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/ops', pageBuilder: (_, s) => _page(s, const DeskPage())),
          GoRoute(path: '/ops/arsiv', pageBuilder: (_, s) => _page(s, const ArchivePage())),
          GoRoute(path: '/ops/musteriler', pageBuilder: (_, s) => _page(s, const CustomersPage())),
          GoRoute(path: '/ops/degerlendirmeler', pageBuilder: (_, s) => _page(s, const RatingsPage())),
          GoRoute(path: '/ops/servis', pageBuilder: (_, s) => _page(s, const RoutePage())),
          GoRoute(path: '/ops/kasa', pageBuilder: (_, s) => _page(s, const CashPage())),
          GoRoute(path: '/ops/analiz', pageBuilder: (_, s) => _page(s, const AnalyticsPage())),
          GoRoute(path: '/ops/ayarlar', pageBuilder: (_, s) => _page(s, const SettingsPage())),
          GoRoute(path: '/ops/sifre', pageBuilder: (_, s) => _page(s, const PasswordPage())),
          GoRoute(path: '/ops/cihazlar', pageBuilder: (_, s) => _page(s, const DevicesPage())),
        ],
      ),
    ],
  );
  currentLocation = () {
    try {
      return router.state.uri.toString();
    } catch (_) {
      return '/ops';
    }
  };
  ref.onDispose(router.dispose);
  return router;
});
