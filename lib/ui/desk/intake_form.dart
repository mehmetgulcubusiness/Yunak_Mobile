import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/endpoints.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../widgets/common.dart';

/// Yeni fiş formunun durumu. Sheet kapansa da kalır (yanlışlıkla kapanan formdaki yazılar silinmez).
class IntakeController extends ChangeNotifier {
  String service = 'carpet_wash';
  final phone = TextEditingController();
  final name = TextEditingController();
  final area = TextEditingController();
  final rate = TextEditingController();
  final amount = TextEditingController();
  final address = TextEditingController();
  final note = TextEditingController();
  final reference = TextEditingController();
  bool referenceTouched = false;
  String? suggested;
  CustomerRow? known;
  Map<String, String> errors = {};
  String? referenceOffer;
  bool busy = false;
  int _ticket = 0;

  bool get dirty => [phone, name, amount, address, note, area, rate].any((c) => c.text.trim().isNotEmpty);
  String get shownReference => referenceTouched ? reference.text : (suggested ?? '');

  void changed() => notifyListeners();

  void clearError(String key) {
    if (errors.remove(key) != null) notifyListeners();
  }

  void setSuggested(String? value) {
    suggested = value;
    if (!referenceTouched) reference.text = value ?? '';
    notifyListeners();
  }

  void fill(CustomerCard card) {
    _ticket++;
    name.text = card.name.length > nameMax ? card.name.substring(0, nameMax) : card.name;
    phone.text = maskPhone(displayPhone(card.phone));
    final a = card.address ?? '';
    address.text = a.length > addressMax ? a.substring(0, addressMax) : a;
    note.clear();
    known = null;
    errors = {};
    notifyListeners();
  }

  Future<void> lookup(Api api) async {
    final ticket = ++_ticket;
    final e164 = parsePhone(phone.text);
    if (e164 == null) {
      known = null;
      if (phone.text.trim().isNotEmpty) errors['phone'] = 'Geçerli bir cep telefonu girin (05xx xxx xx xx).';
      notifyListeners();
      return;
    }
    try {
      final page = await api.customers.list(q: e164.substring(3));
      if (ticket != _ticket) return;
      final match = page.items.where((r) => r.phone == e164).firstOrNull;
      known = match;
      if (match != null) {
        name.text = match.name;
        errors.remove('name');
        if (address.text.trim().isEmpty && (match.address ?? '').isNotEmpty) address.text = match.address!;
      }
      notifyListeners();
    } catch (_) {
      // Arama başarısızsa form elle doldurulur.
    }
  }

  void recalc() {
    final product = meterProduct(area.text, rate.text);
    final total = meterTotal(area.text, rate.text);
    if (product != null && product > amountMax) {
      errors['amount'] = "Toplam 1.000.000 ₺'yi geçiyor.";
    } else {
      errors.remove('amount');
      if (total != null) amount.text = formatAmount(parseAmount(total).value);
    }
    notifyListeners();
  }

  void resetAfterOpen() {
    for (final c in [phone, name, area, rate, amount, address, note, reference]) {
      c.clear();
    }
    referenceTouched = false;
    known = null;
    errors = {};
    referenceOffer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in [phone, name, area, rate, amount, address, note, reference]) {
      c.dispose();
    }
    super.dispose();
  }
}

class IntakeForm extends ConsumerStatefulWidget {
  const IntakeForm({super.key, required this.c, required this.onOpened});
  final IntakeController c;
  final VoidCallback onOpened;

  @override
  ConsumerState<IntakeForm> createState() => _IntakeFormState();
}

class _IntakeFormState extends ConsumerState<IntakeForm> {
  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();

  IntakeController get c => widget.c;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus) c.lookup(ref.read(apiProvider));
    });
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && c.name.text.trim().isNotEmpty) {
        final o = checkPersonName(c.name.text);
        if (!o.ok) {
          c.errors['name'] = o.error!;
          c.changed();
        }
      }
    });
    if (c.suggested == null) _loadSuggestion();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _phoneFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSuggestion() async {
    try {
      c.setSuggested(await ref.read(apiProvider).orders.suggestedReference());
    } catch (_) {}
  }

  Future<void> _submit({bool allowDuplicate = false}) async {
    if (c.busy) return;
    final product = meterProduct(c.area.text, c.rate.text);
    final checks = runChecks({
      'reference': () => checkReference(c.shownReference),
      'name': () => checkPersonName(c.name.text),
      'phone': () => checkPhone(c.phone.text),
      'amount': () => product != null && product > amountMax ? const Check<double>(null, "Toplam 1.000.000 ₺'yi geçemez.") : parseAmount(c.amount.text),
      'address': () => checkLine(c.address.text, addressMax, 'Adres'),
      'note': () => checkLine(c.note.text, deskNoteMax, 'Not'),
    });
    c.errors = checks.errors;
    c.referenceOffer = null;
    c.changed();
    if (!checks.valid) return;
    final v = checks.values;
    final name = v['name'] as String;
    final sentRef = v['reference'] as String;
    c.busy = true;
    c.changed();
    try {
      final res = await ref.read(apiProvider).orders.open({
        'service': c.service,
        'name': name,
        'phone': v['phone'],
        'reference': sentRef,
        'amount': amountWire(v['amount'] as double?),
        'address': v['address'] ?? '',
        'note': v['note'] ?? '',
        if (allowDuplicate) 'allowDuplicate': true,
      });
      var message = res['replay'] == true ? 'Bu fiş az önce açılmıştı.' : (res['messagesSuppressed'] == true ? 'İş açıldı. Bu müşteriye mesaj gitmez.' : 'İş açıldı.');
      final gotRef = res['reference'];
      if (gotRef is String && gotRef.isNotEmpty && gotRef != sentRef) message += ' $sentRef doluydu, $gotRef verildi.';
      final existing = res['existingCustomer'];
      if (existing is Map && existing['name'] is String && existing['name'] != name) message += ' Müşteri kayıtlı adıyla (${existing['name']}) açıldı.';
      toast(message);
      c.resetAfterOpen();
      c.suggested = null;
      _loadSuggestion();
      widget.onOpened();
    } on ApiError catch (e) {
      if (e.code == 'duplicate_today') {
        c.busy = false;
        c.changed();
        if (!mounted) return;
        final ok = await confirmDialog(context,
            title: 'Bu müşteriye bugün fiş açıldı',
            body: '$name için bugün #${e.extra['reference'] ?? ''} açıldı. Yine de yeni bir fiş açılsın mı?',
            confirmLabel: 'Yine de Aç');
        if (ok != null) await _submit(allowDuplicate: true);
        return;
      }
      if (e.code == 'reference_taken') {
        c.errors['reference'] = e.message;
        var offer = e.extra['suggested'] as String?;
        if (offer == null) {
          try {
            offer = await ref.read(apiProvider).orders.suggestedReference();
          } catch (_) {}
        }
        c.referenceOffer = offer;
      } else {
        final f = fieldOfError(e);
        if (f != null && const ['reference', 'name', 'phone', 'amount', 'address', 'note'].contains(f)) {
          c.errors[f] = e.message;
        } else {
          toast(e.message, tone: ToastTone.bad);
        }
      }
    } finally {
      c.busy = false;
      c.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = serviceOf(c.service);
    final e = c.errors;
    TextField numField(TextEditingController ctl, VoidCallback onBlur) => TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [fnFormatter(filterAmount)],
          style: const TextStyle(fontFeatures: tabular),
          onChanged: (_) => c.recalc(),
          onTapOutside: (_) => onBlur(),
        );
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
          Semantics(
            label: 'Hizmet',
            child: Row(children: [
              for (final s in services)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: s == services.last ? 0 : 8),
                    child: Material(
                      color: c.service == s.value ? C.action : C.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          c.service = s.value;
                          c.changed();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: c.service == s.value ? C.action : C.line)),
                          child: Column(children: [
                            AppIcon(s.icon, size: 22, color: c.service == s.value ? C.gold : C.ink),
                            const SizedBox(height: 6),
                            Text(s.pick, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.service == s.value ? Colors.white : C.ink)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Cep Telefonu',
            error: e['phone'],
            child: PhoneInput(
              controller: c.phone,
              focusNode: _phoneFocus,
              autofocus: true,
              error: e.containsKey('phone'),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                c.known = null;
                c.clearError('phone');
                c.changed();
              },
            ),
          ),
          if (c.known != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(TextSpan(style: const TextStyle(color: C.ok, fontSize: 13), children: [
                const TextSpan(text: 'Kayıtlı müşteri: '),
                TextSpan(text: c.known!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
            ),
            if (c.known!.optedOut) const Notice('Bu müşteri WhatsApp mesajlarını kapattı. Fiş açılır ama mesaj gitmez.', tone: 'warn'),
          ],
          AppField(
            label: 'Müşteri Adı Soyadı',
            error: e['name'],
            child: TextField(
              controller: c.name,
              focusNode: _nameFocus,
              maxLength: nameMax,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: fieldDecoration(hint: 'Ayşe Yılmaz', error: e.containsKey('name')),
              onChanged: (_) => c.clearError('name'),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AppField(
                label: service.unit,
                error: e['area'],
                child: numField(c.area, () {
                  final o = parseAmount(c.area.text);
                  o.ok ? c.clearError('area') : (c..errors['area'] = o.error!).changed();
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppField(
                label: service.unit == 'm²' ? 'm² Fiyatı ₺' : 'Birim Fiyat ₺',
                error: e['rate'],
                child: numField(c.rate, () {
                  final o = parseAmount(c.rate.text);
                  o.ok ? c.clearError('rate') : (c..errors['rate'] = o.error!).changed();
                }),
              ),
            ),
          ]),
          AppField(
            label: 'Toplam Tutar (₺)',
            error: e['amount'],
            child: AmountInput(
              controller: c.amount,
              error: e.containsKey('amount'),
              onChanged: (_) => c.clearError('amount'),
              onBlur: (o) => o.ok ? c.clearError('amount') : (c..errors['amount'] = o.error!).changed(),
            ),
          ),
          AppField(
            label: 'Adres',
            error: e['address'],
            child: TextField(
              controller: c.address,
              maxLength: addressMax,
              minLines: 1,
              maxLines: 3,
              decoration: fieldDecoration(hint: 'İlçe, mahalle, açık adres', error: e.containsKey('address')),
              onChanged: (_) => c.clearError('address'),
            ),
          ),
          AppField(
            label: 'Kısa Not',
            error: e['note'],
            child: TextField(
              controller: c.note,
              maxLength: deskNoteMax,
              decoration: fieldDecoration(hint: 'Kapı kodu, teslim notu', error: e.containsKey('note')),
              onChanged: (_) => c.clearError('note'),
            ),
          ),
          AppField(
            label: 'Fiş / Sipariş No',
            error: e['reference'],
            hint: 'Otomatik verilir, isterseniz değiştirin.',
            note: c.referenceOffer == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () {
                        c.reference.text = c.referenceOffer!;
                        c.referenceTouched = true;
                        c.referenceOffer = null;
                        c.clearError('reference');
                        c.changed();
                      },
                      child: Text('${c.referenceOffer} numarasını kullan'),
                    ),
                  ),
            child: TextField(
              controller: c.reference,
              maxLength: referenceMax,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [fnFormatter(filterReference)],
              style: const TextStyle(fontFeatures: tabular, fontWeight: FontWeight.w600),
              decoration: fieldDecoration(error: e.containsKey('reference')),
              onChanged: (_) {
                c.referenceTouched = c.reference.text.isNotEmpty;
                c.clearError('reference');
              },
            ),
          ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
          child: FilledButton(
            onPressed: c.busy ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            child: Text(c.busy ? 'Kaydediliyor…' : 'Fişi Oluştur'),
          ),
        ),
      ),
    ]);
  }
}

/// Yeni fiş sheet'i: geniş ekranda sağdan panel, telefonda tam ekran.
Future<void> openIntakeSheet(BuildContext context, IntakeController c, VoidCallback onOpened) {
  Widget sheet(BuildContext ctx) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
          child: Row(children: [
            const Expanded(child: Text('Yeni Fiş', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Kapat', onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: IntakeForm(
            c: c,
            onOpened: () {
              Navigator.of(ctx).pop();
              onOpened();
            },
          ),
        ),
      ]);
  if (MediaQuery.sizeOf(context).width > Bp.wide) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(color: C.surface, elevation: 12, child: SizedBox(width: 520, height: double.infinity, child: SafeArea(child: sheet(ctx)))),
      ),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
  return Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (ctx) => Scaffold(backgroundColor: C.surface, body: SafeArea(child: sheet(ctx)))));
}
