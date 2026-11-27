import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/json.dart';
import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../account/account_pages.dart';
import '../auth/register_page.dart' show NewAccountControllers;
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

const _keys = ['name', 'publicPhone', 'alertPhone', 'googleReviewUrl', 'wapioSessionId', 'ibanHolder', 'ibanNumber'];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final Loader<Json> _settings = Loader(() => ref.read(apiProvider).settings.get())..addListener(_onLoad);
  final Map<String, TextEditingController> _c = {for (final k in _keys) k: TextEditingController()};
  Map<String, String> _base = {};
  Map<String, String> _errors = {};
  bool _changingKey = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _settings.load();
    for (final c in _c.values) {
      c.addListener(() => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _settings.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onLoad() {
    if (!mounted) return;
    final d = _settings.data;
    if (d != null) {
      final values = {
        'name': d.str('name'),
        'publicPhone': d.str('publicPhone'),
        'alertPhone': (d.s('alertPhone') ?? '').isEmpty ? '' : maskPhone(displayPhone(d.s('alertPhone'))),
        'googleReviewUrl': d.str('googleReviewUrl'),
        'wapioSessionId': '',
        'ibanHolder': d.str('ibanHolder'),
        'ibanNumber': (d.s('ibanNumber') ?? '').isEmpty ? '' : maskIban(d.s('ibanNumber')),
      };
      _base = values;
      values.forEach((k, v) => _c[k]!.text = v);
      _changingKey = false;
    }
    setState(() {});
  }

  bool get _dirty => _keys.any((k) => _c[k]!.text != (_base[k] ?? ''));

  Future<void> _save({bool clearKey = false}) async {
    final checks = runChecks({
      'name': () => checkBrandName(_c['name']!.text),
      'publicPhone': () => checkPublicPhone(_c['publicPhone']!.text),
      'alertPhone': () => checkPhone(_c['alertPhone']!.text, required: false),
      'googleReviewUrl': () => checkGoogleUrl(_c['googleReviewUrl']!.text),
      'wapioSessionId': () => checkWapio(clearKey ? '' : _c['wapioSessionId']!.text),
      'ibanHolder': () => checkLine(_c['ibanHolder']!.text, nameMax, 'IBAN alıcı adı'),
      'ibanNumber': () => checkIban(_c['ibanNumber']!.text),
    });
    setState(() => _errors = checks.errors);
    if (!checks.valid) return;
    final v = checks.values;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).settings.update({
        'name': v['name'],
        'publicPhone': v['publicPhone'] ?? '',
        'alertPhone': v['alertPhone'] ?? '',
        'googleReviewUrl': v['googleReviewUrl'] ?? '',
        'wapioSessionId': v['wapioSessionId'] ?? '',
        'ibanHolder': v['ibanHolder'] ?? '',
        'ibanNumber': v['ibanNumber'] ?? '',
        if (clearKey) 'wapioSessionClear': true,
      });
      toast(clearKey ? 'WhatsApp bağlantısı kaldırıldı.' : 'Ayarlar kaydedildi.');
      await Future.wait([_settings.load(silent: true), ref.read(sessionProvider.notifier).refresh()]);
    } on ApiError catch (e) {
      final f = fieldOfError(e, {'business': 'name'});
      if (f != null && _keys.contains(f)) {
        setState(() => _errors = {f: e.message});
      } else {
        toast(e.message, tone: ToastTone.bad);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeKey(bool platformLine) async {
    final ok = await confirmDialog(context,
        title: 'WhatsApp bağlantısı kaldırılsın mı?',
        body: platformLine ? 'Mesajlar bundan sonra ortak hattan gider.' : 'Bağlantı kaldırılınca müşterilere mesaj gitmez.',
        confirmLabel: 'Bağlantıyı Kaldır',
        danger: true);
    if (ok != null) await _save(clearKey: true);
  }

  void _edit(String k) => setState(() => _errors.remove(k));

  Widget _text(String k, String label, {String? hint, String? help, int max = 120, TextInputType? keyboard, List<dynamic>? formatters, VoidCallback? onBlur}) => AppField(
        label: label,
        error: _errors[k],
        hint: help,
        child: Focus(
          onFocusChange: (f) => !f ? onBlur?.call() : null,
          child: TextField(
            controller: _c[k],
            maxLength: max,
            keyboardType: keyboard,
            inputFormatters: formatters?.cast(),
            decoration: fieldDecoration(hint: hint, error: _errors.containsKey(k)),
            onChanged: (_) => _edit(k),
          ),
        ),
      );

  Widget _section(String icon, String title, String sub, List<Widget> children) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(9)),
              child: AppIcon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(sub, style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _settings.data;
    final me = ref.watch(sessionProvider.select((s) => s.me));
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await confirmDiscard(context) && context.mounted) Navigator.of(context).pop();
      },
      child: OpsPage(
        title: 'Ayarlar',
        subtitle: 'İşletme bilgileri, WhatsApp ve ekibiniz',
        onRefresh: () => _settings.load(silent: true),
        children: [
          ListState(loading: _settings.loading, hasData: d != null, count: 1, error: _settings.error, stale: _settings.stale, onRetry: () => _settings.load()),
          if (d == null && _settings.loading) const CardSkeleton(count: 3),
          if (d != null)
            LayoutBuilder(builder: (context, box) {
              final form = _form(d);
              final preview = _Preview(values: {for (final k in _keys) k: _c[k]!.text}, settings: d);
              if (box.maxWidth > 900) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: form), const SizedBox(width: 16), SizedBox(width: 340, child: preview)]);
              }
              return Column(children: [form, preview]);
            }),
          if (d != null) const _Team(),
          if (d != null && (me?.isOwner ?? false) && !ref.read(apiClientProvider).cookieMode) ...[const SizedBox(height: 8), const DeleteAccountSection()],
        ],
      ),
    );
  }

  Widget _form(Json d) {
    final keySet = d.b('wapioSessionSet');
    final platformLine = d.b('platformLine');
    return Column(children: [
      _section('building', 'İşletme', 'Müşterilerinizin gördüğü bilgiler', [
        _text('name', 'İşletme Adı', help: 'Müşterilere giden mesajlarda bu ad yazar.'),
        _text('publicPhone', 'Müşterinin Göreceği Telefon', hint: '0216 123 45 67', max: phoneInputMax, keyboard: TextInputType.phone, formatters: [fnFormatter(filterPublicPhone)], onBlur: () {
          final o = checkPublicPhone(_c['publicPhone']!.text);
          setState(() => o.ok ? _errors.remove('publicPhone') : _errors['publicPhone'] = o.error!);
        }),
      ]),
      _section('chat', 'WhatsApp', 'Mesajların çıktığı hat', [
        if (!keySet || _changingKey)
          AppField(
            label: 'WhatsApp Bağlantı Anahtarı',
            error: _errors['wapioSessionId'],
            hint: platformLine ? 'Boş bırakırsanız mesajlar ortak hattan gider.' : 'Anahtar girilmeden müşterilere mesaj gitmez.',
            child: PasswordInput(controller: _c['wapioSessionId']!, error: _errors.containsKey('wapioSessionId'), onChanged: (_) => _edit('wapioSessionId')),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: C.okBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bağlı', style: TextStyle(color: C.ok, fontWeight: FontWeight.w700)),
                  Text('Anahtar güvenlik için gizli: ${d.str('wapioSessionMasked')}', style: const TextStyle(fontSize: 12.5, color: C.inkSoft)),
                ]),
              ),
              TextButton(onPressed: () => setState(() => _changingKey = true), child: const Text('Değiştir')),
              TextButton(style: TextButton.styleFrom(foregroundColor: C.bad), onPressed: _busy ? null : () => _removeKey(platformLine), child: const Text('Kaldır')),
            ]),
          ),
      ]),
      _section('star', 'Puan ve yorumlar', "Düşük puan size, memnun müşteri Google'a", [
        AppField(
          label: 'Düşük Puan Bildirimi Telefonu',
          error: _errors['alertPhone'],
          hint: "Müşteri 1–4 yıldız verirse WhatsApp'tan buraya haber gelir. Boşsa işletme sahibine gider.",
          child: PhoneInput(controller: _c['alertPhone']!, error: _errors.containsKey('alertPhone'), onChanged: (_) => _edit('alertPhone')),
        ),
        _text('googleReviewUrl', 'Google Yorum Linki',
            hint: 'https://g.page/r/…/review', max: googleUrlMax, keyboard: TextInputType.url, help: '5 yıldız veren müşteri bu sayfaya gider. Boşsa teşekkür ekranında kalır.'),
      ]),
      _section('card', 'Ödeme', 'Tek dokunuşla gönderilen IBAN bilgisi', [
        _text('ibanHolder', 'IBAN Alıcı Adı', hint: 'Örn: Yıldız Halı - Ziraat Bankası'),
        _text('ibanNumber', 'IBAN Numarası', hint: 'TR00 0000 0000 0000 0000 0000 00', max: 32, formatters: [fnFormatter(maskIban)], onBlur: () {
          final o = checkIban(_c['ibanNumber']!.text);
          setState(() => o.ok ? _errors.remove('ibanNumber') : _errors['ibanNumber'] = o.error!);
        }),
      ]),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _busy || !_dirty ? null : _save,
          child: Text(_busy ? 'Kaydediliyor…' : (_dirty ? 'Ayarları Kaydet' : 'Kaydedildi')),
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.values, required this.settings});
  final Map<String, String> values;
  final Json settings;

  @override
  Widget build(BuildContext context) {
    final name = values['name']!.trim().isEmpty ? 'İşletme' : values['name']!.trim();
    final connected = settings.b('wapioSessionSet') || values['wapioSessionId']!.trim().isNotEmpty || settings.b('platformLine');
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(k, style: const TextStyle(color: C.muted, fontSize: 12.5))),
            const SizedBox(width: 8),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Müşteriniz böyle görür'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFECE5DD), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Monogram(name, size: 30), const SizedBox(width: 8), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trUpper(name), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Merhaba Ayşe Hanım, ürünleriniz özenle temizlenmek üzere teslim alındı.\nFiş No: #HK1001\nBizi tercih ettiğiniz için teşekkür ederiz.',
                    style: TextStyle(fontSize: 13, height: 1.4)),
                const Align(alignment: Alignment.centerRight, child: Text('10:24 ✓✓', style: TextStyle(fontSize: 11, color: C.muted))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        row('Düşük puan bildirimi', values['alertPhone']!.isEmpty ? 'Sizin telefonunuza gelir' : values['alertPhone']!),
        row('Google yorum sayfası', values['googleReviewUrl']!.trim().isEmpty ? 'Link yok, müşteri teşekkür ekranında kalır' : 'Eklendi'),
        row('WhatsApp', connected ? 'Bağlı' : 'Bağlı değil'),
        row('IBAN', values['ibanNumber']!.isEmpty ? 'Kayıtlı IBAN yok' : values['ibanNumber']!),
      ]),
    );
  }
}

// --------------------------------------------------------------------- Ekip
class _Team extends ConsumerStatefulWidget {
  const _Team();
  @override
  ConsumerState<_Team> createState() => _TeamState();
}

class _TeamState extends ConsumerState<_Team> {
  late final Loader<List<TeamMember>> _team = Loader(() => ref.read(apiProvider).settings.team())..addListener(() => mounted ? setState(() {}) : null);
  bool _adding = false;
  final _form = NewAccountControllers();
  String _role = 'staff';
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _team.load();
  }

  @override
  void dispose() {
    _team.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final checks = runChecks({
      'name': () => checkPersonName(_form.name.text),
      'phone': () => checkPhone(_form.phone.text),
      'password': () => checkNewPassword(_form.password.text, _form.phone.text),
      'repeat': () => checkPasswordRepeat(_form.password.text, _form.repeat.text),
    });
    setState(() => _errors = checks.errors);
    if (!checks.valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).settings.addMember({'name': checks.values['name'], 'phone': checks.values['phone'], 'password': _form.password.text, 'role': _role});
      toast('Kişi eklendi.');
      _form.clear();
      setState(() {
        _adding = false;
        _role = 'staff';
      });
      await _team.load(silent: true);
    } on ApiError catch (e) {
      final f = fieldOfError(e);
      if (f == 'name' || f == 'phone' || f == 'password') {
        setState(() => _errors = {f!: e.message});
      } else {
        toast(e.message, tone: ToastTone.bad);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(TeamMember m) async {
    try {
      await ref.read(apiProvider).settings.toggleMember(m.id);
      toast('Kişinin durumu güncellendi.');
      await _team.load(silent: true);
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _team.data;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Ekibiniz',
          sub: 'Personel yalnız işleri, müşterileri ve yorumları görür. Kasa ve ayarlar yöneticiye açıktır.',
          trailing: _adding ? null : FilledButton(onPressed: () => setState(() => _adding = true), child: const Text('Kişi Ekle')),
        ),
        if (_adding) _addForm(),
        ListState(loading: _team.loading, hasData: items != null, count: items?.length ?? 0, error: _team.error, onRetry: () => _team.load(), empty: 'Henüz personel yok.'),
        if (items != null)
          for (final m in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.sunk, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.lineSoft)),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Monogram(m.name, size: 32),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${displayPhone(m.phone)} · ${roleLabels[m.role] ?? m.role}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
                  ]),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Pill(m.active ? 'Aktif' : 'Pasif', tone: m.active ? 'ok' : 'muted'),
                  if (m.canToggle) TextButton(onPressed: () => _toggle(m), child: Text(m.active ? 'Pasif yap' : 'Aktif et')),
                  if (m.canResetPassword)
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (_) => _ResetDialog(member: m));
                        if (ok == true) toast('${m.name} için yeni şifre kaydedildi.');
                      },
                      child: const Text('Şifre sıfırla'),
                    ),
                ]),
              ]),
            ),
      ]),
    );
  }

  Widget _addForm() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Yeni kişi', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          AppField(label: 'Ad Soyad', error: _errors['name'], child: TextField(controller: _form.name, maxLength: nameMax, textCapitalization: TextCapitalization.words, decoration: fieldDecoration(error: _errors.containsKey('name')), onChanged: (_) => setState(() => _errors.remove('name')))),
          AppField(label: 'Cep Telefonu', error: _errors['phone'], child: PhoneInput(controller: _form.phone, error: _errors.containsKey('phone'), onChanged: (_) => setState(() => _errors.remove('phone')))),
          AppField(
            label: 'Şifre',
            error: _errors['password'],
            hint: 'En az 8 karakter; en az bir harf ve bir rakam.',
            child: PasswordInput(controller: _form.password, strength: true, newPassword: true, error: _errors.containsKey('password'), onChanged: (_) => setState(() => _errors.remove('password'))),
          ),
          AppField(label: 'Şifre (tekrar)', error: _errors['repeat'], child: PasswordInput(controller: _form.repeat, newPassword: true, error: _errors.containsKey('repeat'), onChanged: (_) => setState(() => _errors.remove('repeat')))),
          AppField(
            label: 'Yetki',
            child: DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [DropdownMenuItem(value: 'staff', child: Text('Personel (yalnız işler)')), DropdownMenuItem(value: 'admin', child: Text('Yönetici (tam yetki)'))],
              onChanged: (v) => setState(() => _role = v ?? 'staff'),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () {
                _form.clear();
                setState(() {
                  _adding = false;
                  _errors = {};
                });
              },
              child: const Text('Vazgeç'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _add, child: Text(_busy ? 'Ekleniyor…' : 'Kişiyi Ekle')),
          ]),
        ]),
      );
}

class _ResetDialog extends ConsumerStatefulWidget {
  const _ResetDialog({required this.member});
  final TeamMember member;
  @override
  ConsumerState<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends ConsumerState<_ResetDialog> {
  final _p = TextEditingController();
  final _r = TextEditingController();
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _p.dispose();
    _r.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final checks = runChecks({'password': () => checkNewPassword(_p.text, widget.member.phone), 'repeat': () => checkPasswordRepeat(_p.text, _r.text)});
    setState(() => _errors = checks.errors);
    if (!checks.valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).settings.resetPassword(widget.member.id, _p.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _errors = {'password': e.message});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.member.name} için yeni şifre'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Personel bir sonraki girişte bu şifreyi kullanır. Açık oturumları kapanır.', style: TextStyle(color: C.inkSoft)),
              const SizedBox(height: 14),
              AppField(label: 'Yeni şifre', error: _errors['password'], child: PasswordInput(controller: _p, strength: true, newPassword: true, error: _errors.containsKey('password'))),
              AppField(label: 'Yeni şifre (tekrar)', error: _errors['repeat'], child: PasswordInput(controller: _r, newPassword: true, error: _errors.containsKey('repeat'))),
            ]),
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Şifreyi Sıfırla')),
        ],
      );
}
