import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/session/session.dart';

/// Kabuğun gösterge verisi (`GET /api/dashboard`). Hata olursa son bilinen değer kalır.
final dashboardProvider = NotifierProvider<DashboardController, Dashboard?>(DashboardController.new);

class DashboardController extends Notifier<Dashboard?> {
  Future<void>? _loading;

  @override
  Dashboard? build() {
    ref.watch(sessionProvider.select((s) => s.me?.userId));
    scheduleMicrotask(reload);
    return null;
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    if (ref.read(sessionProvider).status != SessionStatus.ready) return;
    try {
      state = await ref.read(apiProvider).reports.dashboard();
    } catch (_) {
      // Son bilinen değer kalır.
    }
  }
}
