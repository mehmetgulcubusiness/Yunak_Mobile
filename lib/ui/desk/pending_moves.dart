import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/api/api_error.dart';
import '../../core/api/endpoints.dart';
import '../../core/session/session.dart';
import '../widgets/common.dart';

const undoSeconds = 5;

const doneLabels = {
  'washing': 'Yıkamaya alındı',
  'delivered': 'Teslim edildi',
  'scheduled': 'Randevu verildi',
  'in_progress': 'İşe başlandı',
  'completed': 'İş bitti',
  'received': 'Teslim alındı',
};

class PendingMove {
  PendingMove(this.orderId, this.reference, this.to, this.onDone) : left = undoSeconds;
  final String orderId;
  final String reference;
  final String to;
  final VoidCallback onDone;
  int left;
  Timer? timer;
}

/// Geri alınabilir durum ilerletmeleri. Kart dışında tutulur: liste kaydırılınca
/// kart yok olsa da sayaç sürer. Sayfa kapanınca bekleyenler hemen gönderilir.
final pendingMovesProvider = ChangeNotifierProvider<PendingMoves>((ref) => PendingMoves(ref.read(apiProvider)));

class PendingMoves extends ChangeNotifier {
  PendingMoves(this._api);
  final Api _api;
  final Map<String, PendingMove> _items = {};

  PendingMove? of(String orderId) => _items[orderId];
  bool get any => _items.isNotEmpty;

  void start(String orderId, String reference, String to, VoidCallback onDone) {
    if (_items.containsKey(orderId)) return;
    final p = PendingMove(orderId, reference, to, onDone);
    p.timer = Timer.periodic(const Duration(seconds: 1), (t) {
      p.left--;
      if (p.left <= 0) {
        t.cancel();
        _send(p);
      } else {
        notifyListeners();
      }
    });
    _items[orderId] = p;
    notifyListeners();
  }

  void undo(String orderId) {
    final p = _items.remove(orderId);
    if (p == null) return;
    p.timer?.cancel();
    notifyListeners();
    toast('İşlem geri alındı.');
  }

  Future<void> _send(PendingMove p) async {
    _items.remove(p.orderId);
    notifyListeners();
    try {
      await _api.orders.advance(p.orderId, p.to);
      toast('${doneLabels[p.to] ?? 'Durum güncellendi'}: #${p.reference}');
    } on ApiError catch (e) {
      toast(e.message, tone: ToastTone.bad);
    } catch (_) {
      toast('İşlem yapılamadı.', tone: ToastTone.bad);
    }
    p.onDone();
  }

  /// Sayfadan çıkılırken: bekleyenler beklemeden gönderilir.
  void flushAll() {
    final pending = _items.values.toList();
    for (final p in pending) {
      p.timer?.cancel();
    }
    if (pending.isEmpty) return;
    scheduleMicrotask(() {
      for (final p in pending) {
        unawaited(_send(p));
      }
    });
  }

  @override
  void dispose() {
    flushAll();
    super.dispose();
  }
}
