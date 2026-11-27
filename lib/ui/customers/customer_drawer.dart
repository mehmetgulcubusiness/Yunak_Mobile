import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../print/print_slip.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';

/// Müşteri kartını açar: geniş ekranda sağdan panel, telefonda tam ekran.
Future<void> openCustomerDrawer(
  BuildContext context, {
  required String customerId,
  VoidCallback? onChanged,
  void Function(CustomerCard card)? onFill,
}) {
  final drawer = CustomerDrawer(customerId: customerId, onChanged: onChanged, onFill: onFill);
  if (MediaQuery.sizeOf(context).width > Bp.wide) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(color: C.surface, elevation: 12, child: SizedBox(width: 480, height: double.infinity, child: drawer)),
      ),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
  return Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => Scaffold(backgroundColor: C.surface, body: SafeArea(child: drawer))));
}

class CustomerDrawer extends ConsumerStatefulWidget {
  const CustomerDrawer({super.key, required this.customerId, this.onChanged, this.onFill});
  final String customerId;
  final VoidCallback? onChanged;
  final void Function(CustomerCard card)? onFill;

  @override
  ConsumerState<CustomerDrawer> createState() => _CustomerDrawerState();
}

class _CustomerDrawerState extends ConsumerState<CustomerDrawer> {
  CustomerCard? _card;
  bool _loading = true;
  bool _missing = false;
  bool _showAll = false;
  bool _busy = false;

  bool _editingNote = false;
  final _note = TextEditingController();

  bool _editing = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_note, _name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final card = await ref.read(apiProvider).customers.card(widget.customerId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
        _missing = card.id.isEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _missing = _card == null;
        });
      }
    }
  }

  bool get _dirty {
    final c = _card;
    if (c == null) return false;
    if (_editingNote && _note.text.trim() != (c.note ?? '')) return true;
    if (_editing && (_name.text.trim() != c.name || parsePhone(_phone.text) != c.phone || _address.text.trim() != (c.address ?? ''))) return true;
    return false;
  }

  Future<void> _close() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit() {
    final c = _card!;
    _name.text = c.name;
    _phone.text = maskPhone(displayPhone(c.phone));
    _address.text = c.address ?? '';
    setState(() {
      _errors = {};
      _editing = true;
    });
  }

  Future<void> _saveInfo() async {
    final checks = runChecks({
      'name': () => checkPersonName(_name.text),
      'phone': () => checkPhone(_phone.text),
      'address': () => checkLine(_address.text, addressMax, 'Adres'),
    });
    setState(() => _errors = checks.errors);
    if (!checks.valid) return;
    await _run(() async {
      try {
        final res = await ref.read(apiProvider).customers.update(widget.customerId, {
          'name': checks.values['name'],
          'phone': checks.values['phone'],
          'address': checks.values['address'] ?? '',
        });
        final patch = res is Map ? asJson(res) : <String, dynamic>{'name': checks.values['name'], 'phone': checks.values['phone'], 'address': checks.values['address']};
        setState(() {
          _card = _card!.merge(patch);
          _editing = false;
        });
        toast('Müşteri bilgileri kaydedildi.');
        widget.onChanged?.call();
      } on ApiError catch (e) {
        final f = fieldOfError(e);
        if (f == 'name' || f == 'phone' || f == 'address') {
          setState(() => _errors = {f!: e.message});
        } else {
          rethrow;
        }
      }
    });
  }

  Future<void> _saveNote() async {
    final value = _note.text.trim();
    await _run(() async {
      final res = await ref.read(apiProvider).customers.saveNote(widget.customerId, value);
      setState(() {
        _card = res is Map && asJson(res).containsKey('id') ? CustomerCard(asJson(res)) : _card!.merge({'note': value.isEmpty ? null : value});
        _editingNote = false;
      });
      toast(value.isEmpty ? 'Not silindi.' : 'Not kaydedildi.');
      widget.onChanged?.call();
    });
  }

  Future<void> _toggleMessages() async {
    final c = _card!;
    final off = !c.optedOut;
    final ok = await confirmDialog(
      context,
      title: off ? 'Mesajlar kapatılsın mı?' : 'Mesajlar yeniden açılsın mı?',
      body: off
          ? '${c.name} adlı müşteriye bundan sonra hiçbir WhatsApp mesajı gitmez (fiş, IBAN, puan linki).'
          : 'Bunu yalnız ${c.name} izin verdiyse yapın. Yeni işlerde bilgilendirme mesajları yeniden gider.',
      confirmLabel: off ? 'Mesajları Kapat' : 'Mesajları Aç',
      danger: off,
    );
    if (ok == null) return;
    await _run(() async {
      final api = ref.read(apiProvider).customers;
      off ? await api.optOut(c.id) : await api.optIn(c.id);
      toast(off ? 'Bu müşteriye artık mesaj gitmez.' : 'Bu müşteriye yeniden mesaj gidecek.');
      await _load();
      widget.onChanged?.call();
    });
  }

  Future<void> _erase() async {
    final c = _card!;
    final ok = await confirmDialog(
      context,
      title: 'Müşteri kaydı silinsin mi? (KVKK)',
      body: 'Bu işlem geri alınamaz. Silinecekler:',
      items: ['Ad soyad', 'Telefon (${displayPhone(c.phone)})', 'Kayıtlı adres', 'Müşteri notu ve fiş notları', 'Müşterinin yorum notları', 'Bekleyen WhatsApp mesajları'],
      confirmLabel: 'Kalıcı Olarak Sil',
      danger: true,
      typeToConfirm: c.name,
    );
    if (ok == null) return;
    await _run(() async {
      await ref.read(apiProvider).customers.erase(c.id);
      toast('Müşteri kaydı silindi.');
      widget.onChanged?.call();
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) Navigator.of(context).pop();
      },
      child: _loading
          ? const Padding(padding: EdgeInsets.all(20), child: CardSkeleton(count: 2))
          : _missing || _card == null
              ? _missingView()
              : _body(_card!),
    );
  }

  Widget _missingView() => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Müşteri bulunamadı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ]),
          const Text('Kayıt silinmiş ya da bu işletmeye ait değil.', style: TextStyle(color: C.muted)),
        ]),
      );

  Widget _body(CustomerCard c) {
    final manager = ref.watch(sessionProvider.select((s) => s.me?.isManager ?? false));
    final loyalty = loyaltyOf(c.orderCount);
    final orders = c.orders;
    final shown = _showAll ? orders : orders.take(3).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Monogram(c.name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Pill(loyalty.label, tone: loyalty.gold ? 'gold' : 'muted'),
            const SizedBox(height: 4),
            Text(displayPhone(c.phone), style: const TextStyle(color: C.inkSoft, fontFeatures: tabular)),
          ]),
        ),
        IconButton(tooltip: 'Kapat', onPressed: _close, icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 12),
      InkWell(
        onTap: (c.address ?? '').isEmpty ? _startEdit : () => openMaps(c.address!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            const AppIcon('pin', size: 16, color: C.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text((c.address ?? '').isEmpty ? 'Adres eklenmemiş · Ekle' : c.address!,
                  style: TextStyle(color: (c.address ?? '').isEmpty ? C.muted : C.ink, decoration: (c.address ?? '').isEmpty ? TextDecoration.underline : null)),
            ),
          ]),
        ),
      ),
      if (c.optedOut) const Padding(padding: EdgeInsets.only(top: 8), child: Notice('Bu müşteriye WhatsApp mesajı gitmiyor.', tone: 'warn')),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (widget.onFill != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onFill!(c);
            },
            icon: const AppIcon('plus', size: 16, color: C.gold),
            label: const Text('Yeni Fiş Aç'),
          ),
        OutlinedButton.icon(onPressed: () => callPhone(c.phone), icon: const AppIcon('call', size: 16), label: const Text('Ara')),
        OutlinedButton.icon(onPressed: () => openWhatsapp(c.phone), icon: const AppIcon('chat', size: 16), label: const Text('WhatsApp')),
        Tooltip(
          message: c.optedOut ? 'Bu müşteriye mesaj gitmiyor.' : '',
          child: OutlinedButton.icon(
            onPressed: c.optedOut || _busy
                ? null
                : () => _run(() async {
                      await ref.read(apiProvider).customers.sendIban(c.id);
                      toast('IBAN müşteriye gönderiliyor.');
                    }),
            icon: const AppIcon('card', size: 16),
            label: const Text('IBAN Gönder'),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _kpi('Sipariş', '${c.orderCount}'),
        _kpi('Toplam', money(c.totalTry) ?? '0 ₺'),
        _kpi('Son puan', c.lastStars != null && c.lastStars! > 0 ? '${c.lastStars} ★' : '—'),
      ]),
      const SizedBox(height: 18),
      Text('Fişler ${orders.length}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 8),
      if (orders.isEmpty) const Text('Bu müşterinin henüz fişi yok.', style: TextStyle(color: C.muted)),
      for (final o in shown) _slip(c, o),
      if (orders.length > 3)
        TextButton(onPressed: () => setState(() => _showAll = !_showAll), child: Text(_showAll ? 'Daha az göster' : 'Tümünü göster (${orders.length})')),
      const SizedBox(height: 14),
      _noteBlock(c),
      const SizedBox(height: 14),
      if (_editing) _editForm(c) else _footer(c, manager),
    ]);
  }

  Widget _kpi(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.sunk, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lineSoft)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFeatures: tabular)),
          ]),
        ),
      );

  Widget _slip(CustomerCard c, CustomerSlip o) {
    final finished = o.status == 'delivered' || o.status == 'completed';
    final muted = o.status == 'cancelled' || o.voided;
    final (bg, border) = muted ? (C.sunk, C.lineSoft) : (finished ? (C.okBg, const Color(0xFFCFE3D4)) : (C.surface, C.line));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '#${o.reference}  ', style: const TextStyle(color: C.muted, fontFeatures: tabular)),
              TextSpan(text: serviceOf(o.serviceType).title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          ),
          Text(money(o.amount) ?? '—', style: TextStyle(fontWeight: FontWeight.w600, color: muted ? C.muted : C.ink)),
          const SizedBox(width: 8),
          Pill(o.voided ? 'Geçersiz' : (statusLabels[o.status] ?? o.status), tone: muted ? 'muted' : (finished ? 'ok' : 'plain')),
        ]),
        if ((o.note ?? '').trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• ${o.note!.trim()}', style: const TextStyle(color: C.inkSoft, fontSize: 13))),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text([formatStamp(o.createdAt), if ((o.actorName ?? '').isNotEmpty) o.actorName].join(' · '), style: const TextStyle(color: C.muted, fontSize: 12.5)),
        ),
        const SizedBox(height: 4),
        Row(children: [
          if (muted)
            const Expanded(child: Text('Kasaya sayılmaz', style: TextStyle(color: C.muted, fontSize: 12.5)))
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.go(Uri(path: '/ops', queryParameters: {'tab': finished ? 'delivered' : 'open', 'q': o.reference}).toString());
                  },
                  child: const Text('İş kartına git →'),
                ),
              ),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
            onPressed: () {
              final t = ref.read(sessionProvider).me?.tenant;
              printSlip(SlipData(
                businessName: t?.name ?? 'İşletme',
                businessPhone: t?.phone,
                reference: o.reference,
                createdAt: o.createdAt,
                customerName: c.name,
                phone: c.phone,
                address: c.address,
                serviceType: o.serviceType,
                deskNote: o.note,
                amount: o.amount,
              ));
            },
            icon: const AppIcon('print', size: 15),
            label: const Text('Fişi Yazdır', style: TextStyle(fontSize: 13)),
          ),
        ]),
      ]),
    );
  }

  Widget _noteBlock(CustomerCard c) {
    if (_editingNote) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _note,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: customerNoteMax,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Örn. Teslimattan önce aranacak, kapıda nakit ödeme.'),
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              Text('$currentLength/$maxLength · Müşteriye gönderilmez', style: const TextStyle(fontSize: 12, color: C.muted)),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => setState(() => _editingNote = false), child: const Text('Vazgeç')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy || _note.text.trim() == (c.note ?? '') ? null : _saveNote, child: const Text('Kaydet')),
        ]),
      ]);
    }
    void start() {
      _note.text = c.note ?? '';
      setState(() => _editingNote = true);
    }

    if ((c.note ?? '').isEmpty) {
      return InkWell(
        onTap: start,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
          child: const Text('＋ Müşteri veya adres notu ekle…', style: TextStyle(color: C.muted)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.undoBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF3E3B5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppIcon('note', size: 16, color: C.warn),
        const SizedBox(width: 8),
        Expanded(child: Text(c.note!, style: const TextStyle(height: 1.4))),
        TextButton(onPressed: start, child: const Text('Düzenle')),
      ]),
    );
  }

  Widget _footer(CustomerCard c, bool manager) => Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton.icon(onPressed: _startEdit, icon: const AppIcon('pencil', size: 15), label: const Text('Bilgileri düzenle')),
        TextButton.icon(
          onPressed: _busy ? null : _toggleMessages,
          icon: AppIcon(c.optedOut ? 'chat' : 'mute', size: 15),
          label: Text(c.optedOut ? 'Mesajları aç' : 'Mesajları kapat'),
        ),
        if (manager)
          Tooltip(
            message: 'Ad, telefon ve adres silinir.',
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: C.bad),
              onPressed: _busy ? null : _erase,
              icon: const AppIcon('trash', size: 15, color: C.bad),
              label: const Text('Kaydı sil'),
            ),
          ),
      ]);

  Widget _editForm(CustomerCard c) {
    final changed = _name.text.trim() != c.name || parsePhone(_phone.text) != c.phone || _address.text.trim() != (c.address ?? '');
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppField(
          label: 'Ad Soyad',
          error: _errors['name'],
          child: TextField(controller: _name, maxLength: nameMax, textCapitalization: TextCapitalization.words, decoration: fieldDecoration(error: _errors.containsKey('name')), onChanged: (_) => setState(() => _errors.remove('name'))),
        ),
        AppField(
          label: 'Telefon',
          error: _errors['phone'],
          child: PhoneInput(controller: _phone, error: _errors.containsKey('phone'), onChanged: (_) => setState(() => _errors.remove('phone'))),
        ),
        AppField(
          label: 'Açık Adres',
          error: _errors['address'],
          child: TextField(controller: _address, maxLength: addressMax, minLines: 1, maxLines: 3, decoration: fieldDecoration(error: _errors.containsKey('address')), onChanged: (_) => setState(() => _errors.remove('address'))),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => setState(() => _editing = false), child: const Text('Vazgeç')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy || !changed ? null : _saveInfo, child: const Text('Kaydet')),
        ]),
      ]),
    );
  }
}
