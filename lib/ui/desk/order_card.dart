import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../print/print_slip.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import 'pending_moves.dart';

Move? primaryMove(DeskOrder o) {
  final moves = o.moves;
  if (moves.isEmpty) return null;
  Move? find(String to) => moves.where((m) => m.to == to).firstOrNull;
  return switch (o.status) {
    'received' => find('washing'),
    'draft' => find('scheduled') ?? moves.first,
    'scheduled' => find('in_progress') ?? moves.first,
    'washing' || 'in_progress' => find('delivered') ?? find('completed'),
    _ => null,
  };
}

const _bigLabels = {
  'washing': 'Yıkamaya Al →',
  'in_progress': 'İşe Başla →',
  'delivered': 'Teslim Et →',
  'completed': 'İşi Bitir →',
  'scheduled': 'Randevu Ver →',
};

const _refreshCodes = {
  'illegal_transition',
  'not_cancellable',
  'not_voidable',
  'invalid_status',
};

class OrderCard extends ConsumerStatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onChanged,
    this.onOpenCustomer,
  });
  final DeskOrder order;
  final VoidCallback onChanged;
  final void Function(String customerId)? onOpenCustomer;

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _busy = false;
  bool _amending = false;
  final _area = TextEditingController();
  final _rate = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Map<String, String> _errors = {};

  DeskOrder get o => widget.order;

  @override
  void dispose() {
    for (final c in [_area, _rate, _amount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiError catch (e) {
      toast(e.message, tone: ToastTone.bad);
      if (_refreshCodes.contains(e.code)) widget.onChanged();
    } catch (_) {
      toast('İşlem yapılamadı.', tone: ToastTone.bad);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advance(String to) => ref
      .read(pendingMovesProvider)
      .start(o.id, o.reference, to, widget.onChanged);

  Future<void> _askRating() => _run(() async {
    final res = await ref.read(apiProvider).orders.requestRating(o.id);
    if (res['outcome'] == 'queued') {
      toast('Puan linki müşteriye gönderiliyor.');
    } else {
      toast(
        'Puan linki gönderilmedi. ${skipReasonLabels[res['reason']] ?? ''}'
            .trim(),
        tone: ToastTone.bad,
      );
    }
    widget.onChanged();
  });

  Future<void> _retry() => _run(() async {
    final n = await ref.read(apiProvider).orders.retry(o.id);
    n > 0
        ? toast('Mesaj yeniden gönderildi.')
        : toast('Gönderilecek mesaj bulunamadı.', tone: ToastTone.bad);
    widget.onChanged();
  });

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: '#${o.reference} iptal edilsin mi?',
      body: 'İş iptal edilir, bekleyen mesajları gönderilmez.',
      confirmLabel: 'İşi İptal Et',
      danger: true,
    );
    if (ok == null) return;
    await _run(() async {
      await ref.read(apiProvider).orders.cancel(o.id);
      toast('İş iptal edildi.');
      widget.onChanged();
    });
  }

  Future<void> _void() async {
    final ok = await confirmDialog(
      context,
      title: '#${o.reference} teslimatı geçersiz sayılsın mı?',
      body: 'Durum değişmez. Şunlar olur:',
      items: const [
        'Gönderilmemiş WhatsApp mesajları düşer.',
        'Fiş kasa ve müşteri toplamlarına girmez.',
        'Puan linki gönderilmez.',
      ],
      confirmLabel: 'Geçersiz Say',
      danger: true,
    );
    if (ok == null) return;
    await _run(() async {
      await ref.read(apiProvider).orders.voidOrder(o.id);
      toast('Teslimat geçersiz sayıldı.');
      widget.onChanged();
    });
  }

  void _print() {
    final t = ref.read(sessionProvider).me?.tenant;
    printSlip(
      SlipData(
        businessName: t?.name ?? 'İşletme',
        businessPhone: t?.phone,
        reference: o.reference,
        createdAt: o.createdAt,
        customerName: o.customerName,
        phone: o.phone,
        address: o.address,
        serviceType: o.serviceType,
        deskNote: o.deskNote,
        amount: o.amount,
      ),
    );
  }

  void _openAmend() {
    _area.clear();
    _rate.clear();
    _amount.text = amountField(o.amount);
    _note.text = o.deskNote ?? '';
    setState(() {
      _errors = {};
      _amending = true;
    });
  }

  void _recalc() {
    final product = meterProduct(_area.text, _rate.text);
    final total = meterTotal(_area.text, _rate.text);
    setState(() {
      if (product != null && product > amountMax) {
        _errors['amount'] = "Toplam 1.000.000 ₺'yi geçiyor.";
      } else {
        _errors.remove('amount');
        if (total != null) {
          _amount.text = formatAmount(parseAmount(total).value);
        }
      }
    });
  }

  Future<void> _saveAmend() async {
    final product = meterProduct(_area.text, _rate.text);
    final checks = runChecks({
      'amount': () => product != null && product > amountMax
          ? const Check<double>(null, "Toplam 1.000.000 ₺'yi geçemez.")
          : parseAmount(_amount.text),
      'note': () => checkLine(_note.text, deskNoteMax, 'Not'),
    });
    setState(() => _errors = checks.errors);
    if (!checks.valid) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .orders
          .quote(
            o.id,
            amount: amountWire(checks.values['amount'] as double?),
            note: (checks.values['note'] as String?) ?? '',
          );
      toast('Tutar ve not güncellendi.');
      if (mounted) setState(() => _amending = false);
      widget.onChanged();
    } on ApiError catch (e) {
      final f = fieldOfError(e);
      if (f == 'amount' || f == 'note') {
        setState(() => _errors = {f!: e.message});
      } else {
        toast(e.message, tone: ToastTone.bad);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingMovesProvider).of(o.id);
    final manager = ref.watch(
      sessionProvider.select((s) => s.me?.isManager ?? false),
    );
    final service = serviceOf(o.serviceType);
    final finished = o.status == 'delivered' || o.status == 'completed';
    final cancelled = o.status == 'cancelled';
    final closed = finished || cancelled || o.voided;
    final next = o.voided || cancelled ? null : primaryMove(o);
    final extras = o.voided || cancelled
        ? <Move>[]
        : o.moves.where((m) => m.to != next?.to).toList();
    final address = (o.address ?? '').trim();
    final desk = (o.deskNote ?? '').trim();
    final extraNote = desk != address ? desk : '';
    final canAmend = !closed || manager;
    final canMessage = !cancelled && !o.voided;
    final stuck = o.whatsappStuck && canMessage;
    final preview = RegExp(
      r'^[A-Za-z0-9_-]{43}$',
    ).hasMatch(o.previewToken ?? '');
    final crisis = o.feedback != null;
    final cashNote = cancelled || o.voided
        ? 'Kasaya sayılmaz'
        : (finished
              ? 'Kasaya yazıldı'
              : (o.amount == null ? 'Fiyat girilmedi' : 'Teslimde kasaya'));
    final stripe = switch (o.status) {
      'received' => C.ink,
      'washing' || 'in_progress' => C.midBar,
      'delivered' || 'completed' => C.ok,
      _ => C.gold,
    };
    final today = istanbulDayKey(o.createdAt) == istanbulDayKey(DateTime.now());

    final who = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppIcon(
            service.icon,
            size: 20,
            color: closed ? C.muted : C.ink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  InkWell(
                    onTap: widget.onOpenCustomer == null || o.customerId.isEmpty
                        ? null
                        : () => widget.onOpenCustomer!(o.customerId),
                    child: Text(
                      o.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: closed ? C.muted : C.ink,
                        decoration: widget.onOpenCustomer == null
                            ? null
                            : TextDecoration.underline,
                        decorationColor: C.lineStrong,
                      ),
                    ),
                  ),
                  Text(
                    '#${o.reference}',
                    style: const TextStyle(
                      color: C.muted,
                      fontSize: 12.5,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (address.isNotEmpty)
                InkWell(
                  onTap: () => openMaps(address),
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.inkSoft, fontSize: 13),
                  ),
                )
              else
                const Text(
                  'Adres yok',
                  style: TextStyle(color: C.stone, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );

    final svc = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          service.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
        ),
        Text(
          extraNote.isEmpty ? '—' : extraNote,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: C.muted, fontSize: 12.5),
        ),
      ],
    );

    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        InkWell(
          onTap: () => callPhone(o.phone),
          child: Text(
            displayPhone(o.phone),
            style: const TextStyle(fontSize: 13.5, fontFeatures: tabular),
          ),
        ),
        Text(
          [
            today
                ? 'Bugün ${formatClock(o.createdAt)}'
                : formatDay(o.createdAt),
            if ((o.actorName ?? '').isNotEmpty) o.actorName,
          ].join(' • '),
          style: const TextStyle(color: C.muted, fontSize: 12.5),
        ),
      ],
    );

    final now = cancelled
        ? const Pill('İptal edildi', tone: 'muted')
        : o.voided
        ? const Pill('Geçersiz sayıldı', tone: 'muted')
        : StageBadge(status: o.status, serviceType: o.serviceType, wide: true);

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          money(o.amount) ?? '—',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
            color: closed && !finished ? C.muted : C.ink,
            fontFeatures: tabular,
          ),
        ),
        Text(cashNote, style: const TextStyle(color: C.muted, fontSize: 12)),
      ],
    );

    final menuItems = <MoreItem>[
      if (canAmend)
        MoreItem('Tutar ve Not Düzenle', _openAmend, icon: 'pencil'),
      MoreItem('Fişi Yazdır', _print, icon: 'print'),
      if (canMessage)
        MoreItem(
          'IBAN Gönder',
          () => _run(() async {
            await ref.read(apiProvider).orders.sendIban(o.id);
            toast('IBAN müşteriye gönderiliyor.');
          }),
          icon: 'card',
        ),
      for (final m in extras)
        MoreItem(
          m.to == 'delivered'
              ? 'Yıkamadan Teslim Et'
              : (moveLabels[m.to] ?? m.to),
          () => _advance(m.to),
          icon: 'arrow',
        ),
      if (o.cancellable)
        MoreItem('İşi İptal Et', _cancel, danger: true, icon: 'trash'),
      if (o.voidable && manager)
        MoreItem('Teslimatı Geçersiz Say', _void, danger: true, icon: 'flag'),
    ];

    Widget mainButton() {
      if (pending != null) {
        return Semantics(
          label:
              '${doneLabels[pending.to] ?? 'Durum güncellendi'} olarak ${pending.left} saniye sonra kaydedilecek.',
          button: true,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: C.undoBg,
                    side: const BorderSide(color: C.gold),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => ref.read(pendingMovesProvider).undo(o.id),
                  child: Text(
                    '↶ Geri al · ${pending.left}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                bottom: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pending.left / undoSeconds,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(C.gold),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      if (next == null) return const SizedBox.shrink();
      final label = _bigLabels[next.to] ?? moveLabels[next.to] ?? next.to;
      final button = next.to == 'scheduled'
          ? OutlinedButton(
              onPressed: _busy ? null : () => _advance(next.to),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(label),
            )
          : FilledButton(
              onPressed: _busy ? null : () => _advance(next.to),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(label),
            );
      return SizedBox(width: double.infinity, child: button);
    }

    final actions = Row(
      children: [
        if (pending != null || next != null) Expanded(child: mainButton()),
        if (finished && canMessage && pending == null) ...[
          if (next != null) const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _askRating,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text(
                '★ Yıldız İste',
                style: TextStyle(color: C.goldHover),
              ),
            ),
          ),
        ],
        if (pending == null && next == null && !(finished && canMessage))
          const Spacer(),
        MoreMenu(items: menuItems, disabled: pending != null || _busy),
      ],
    );

    final extra = <Widget>[
      if (stuck)
        _band(
          C.badBg,
          C.bad,
          'WhatsApp mesajı gitmedi.',
          FilledButton(
            onPressed: _busy ? null : _retry,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
            child: const Text('Tekrar Gönder'),
          ),
        ),
      if (crisis)
        _band(
          C.warnBg,
          C.warn,
          'Müşteri ${o.feedback!['stars'] ?? '?'} yıldız verdi.${(o.feedback!['note'] ?? '').toString().trim().isEmpty ? '' : ' “${o.feedback!['note'].toString().trim()}”'}',
          null,
        ),
      if (_amending) _amendForm(service),
      if (preview)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                openExternal('${AppConfig.webBaseUrl}/r/${o.previewToken}'),
            child: const Text('Müşteri Yıldız Ekranını Aç (Test)'),
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: closed && !finished ? C.sunk : C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crisis ? const Color(0xFFE9C98A) : C.line),
        boxShadow: Shadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      // Sol renk şeridi Positioned ile çizilir: IntrinsicHeight, içteki LayoutBuilder ile çalışmaz.
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(
              color: closed && !finished ? C.lineStrong : stripe,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth > 820) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 26, child: who),
                            Expanded(flex: 16, child: svc),
                            Expanded(
                              flex: 16,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: contact,
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: now,
                              ),
                            ),
                            Expanded(flex: 10, child: amount),
                            const SizedBox(width: 12),
                            SizedBox(width: 230, child: actions),
                          ],
                        ),
                        ...extra.map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: w,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: who),
                          const SizedBox(width: 8),
                          amount,
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: svc),
                          const SizedBox(width: 8),
                          contact,
                        ],
                      ),
                      const SizedBox(height: 10),
                      now,
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      actions,
                      ...extra.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: w,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _band(Color bg, Color fg, String text, Widget? action) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _amendForm(Service service) {
    final unit = service.unit;
    final preview = _errors['amount'] == null
        ? amountPreview(_amount.text)
        : null;
    final areaField = AppField(
      label: unit,
      child: TextField(
        controller: _area,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [fnFormatter(filterAmount)],
        onChanged: (_) => _recalc(),
      ),
    );
    final rateField = AppField(
      label: unit == 'm²' ? 'm² Fiyatı ₺' : 'Birim Fiyat ₺',
      child: TextField(
        controller: _rate,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [fnFormatter(filterAmount)],
        onChanged: (_) => _recalc(),
      ),
    );
    final amountF = AppField(
      label: 'Toplam Tutar (₺)',
      error: _errors['amount'],
      hint: preview,
      child: AmountInput(
        controller: _amount,
        error: _errors.containsKey('amount'),
        onChanged: (_) => setState(() => _errors.remove('amount')),
        onBlur: (o) => setState(
          () => o.error != null
              ? _errors['amount'] = o.error!
              : _errors.remove('amount'),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.sunk,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: areaField),
              const SizedBox(width: 10),
              Expanded(child: rateField),
            ],
          ),
          amountF,
          AppField(
            label: 'Kısa Not',
            error: _errors['note'],
            child: TextField(
              controller: _note,
              maxLength: deskNoteMax,
              decoration: fieldDecoration(
                hint: 'Kapı kodu, teslim notu',
                error: _errors.containsKey('note'),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _amending = false),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _saveAmend,
                child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Teslim edilenleri teslim gününe göre bantlara böler.
class DayGroups extends StatelessWidget {
  const DayGroups({
    super.key,
    required this.items,
    required this.days,
    required this.itemBuilder,
  });
  final List<DeskOrder> items;
  final List<DaySummary> days;
  final Widget Function(DeskOrder) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<DeskOrder>)>[];
    for (final item in items) {
      final key = istanbulDayKey(item.deliveredAt ?? item.createdAt);
      if (groups.isNotEmpty && groups.last.$1 == key) {
        groups.last.$2.add(item);
      } else {
        groups.add((key, [item]));
      }
    }
    final byDay = {for (final d in days) d.day: d};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (key, list) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayHeading(key.isEmpty ? null : key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${byDay[key]?.count ?? list.length} teslim${byDay[key]?.totalTry != null ? ' · ${money(byDay[key]!.totalTry)}' : ''}',
                  style: const TextStyle(
                    color: C.muted,
                    fontSize: 13,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
          ...list.map(itemBuilder),
        ],
      ],
    );
  }
}
