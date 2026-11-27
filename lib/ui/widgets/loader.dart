import 'dart:async';

import 'package:flutter/widgets.dart';

/// Bir uç noktadan veri yükleyen küçük durum: ilk yükleme, sessiz yenileme,
/// hata ve "eski veri" (sessiz yenileme başarısız ama elde veri var).
class Loader<T> extends ChangeNotifier {
  Loader(this._fetch);
  Future<T> Function() _fetch;

  T? data;
  Object? error;
  bool loading = false;
  bool stale = false;
  int _ticket = 0;
  bool _disposed = false;

  set fetch(Future<T> Function() f) => _fetch = f;

  Future<void> load({bool silent = false}) async {
    final ticket = ++_ticket;
    if (!silent) {
      loading = true;
      error = null;
      scheduleMicrotask(_notify);
    }
    try {
      final value = await _fetch();
      if (ticket != _ticket) return;
      data = value;
      error = null;
      stale = false;
    } catch (e) {
      if (ticket != _ticket) return;
      if (silent && data != null) {
        stale = true;
      } else {
        error = e;
      }
    } finally {
      if (ticket == _ticket) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
