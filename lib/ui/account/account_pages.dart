import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/format/format.dart';
import '../../core/models/models.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../shell/ops_shell.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

// ------------------------------------------------------- Şifremi değiştir
class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});
  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _dirty => [_current, _next, _repeat].any((c) => c.text.isNotEmpty);

  Future<void> _submit() async {
    final phone = ref.read(sessionProvider).me?.phone;
    final errors = <String, String>{};
    if (_current.text.isEmpty) errors['currentPassword'] = 'Mevcut şifrenizi girin.';
    final next = checkNewPassword(_next.text, phone);
    if (!next.ok) {
      errors['newPassword'] = next.error!;
    } else if (_next.text == _current.text) {
      errors['newPassword'] = 'Yeni şifre eskisiyle aynı olamaz.';
    }
    final repeat = checkPasswordRepeat(_next.text, _repeat.text);
    if (!repeat.ok) errors['repeat'] = repeat.error!;
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.changePassword(_current.text, _next.text);
      for (final c in [_current, _next, _repeat]) {
        c.clear();
      }
      toast('Şifreniz değiştirildi. Diğer cihazlardaki oturumlar kapanır.');
    } on ApiError catch (e) {
      if (e.status == 401 && e.code == 'unauthenticated') {
        await ref.read(sessionProvider.notifier).dropLocal(notice: LoginNotice.passwordChanged);
        return;
      }
      final field = e.status == 404
          ? 'currentPassword'
          : fieldOfError(e, {'invalid_credentials': 'currentPassword', 'wrong_password': 'currentPassword', 'password_unchanged': 'newPassword', 'password': 'newPassword'});
      final message = e.status == 404 ? 'Sunucu şifre değiştirmeyi henüz desteklemiyor.' : e.message;
      if (field == 'currentPassword' || field == 'newPassword') {
        setState(() => _errors = {field!: message});
      } else {
        toast(message, tone: ToastTone.bad);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await confirmDiscard(context) && context.mounted) Navigator.of(context).pop();
      },
      child: OpsPage(
        title: 'Şifremi değiştir',
        maxWidth: 520,
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Yeni şifre en az 8 karakter olmalı, en az bir harf ve bir rakam içermeli ve telefon numaranızla aynı olmamalı.',
                    style: TextStyle(color: C.muted, fontSize: 13.5, height: 1.4)),
              ),
              AppField(label: 'Mevcut şifre', error: _errors['currentPassword'], child: PasswordInput(controller: _current, error: _errors.containsKey('currentPassword'), onChanged: (_) => setState(() => _errors.remove('currentPassword')))),
              AppField(label: 'Yeni şifre', error: _errors['newPassword'], child: PasswordInput(controller: _next, strength: true, newPassword: true, error: _errors.containsKey('newPassword'), onChanged: (_) => setState(() => _errors.remove('newPassword')))),
              AppField(label: 'Yeni şifre (tekrar)', error: _errors['repeat'], child: PasswordInput(controller: _repeat, newPassword: true, error: _errors.containsKey('repeat'), onChanged: (_) => setState(() => _errors.remove('repeat')), onSubmitted: (_) => _submit())),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Kaydediliyor…' : 'Şifreyi Değiştir')),
            ]),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Cihazlarım
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});
  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  late final Loader<List<SessionView>> _list = Loader(() => ref.read(apiProvider).auth.sessions())..addListener(() => mounted ? setState(() {}) : null);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _list.load();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _revoke(SessionView s) async {
    final ok = await confirmDialog(context,
        title: 'Bu oturum kapatılsın mı?', body: '${_name(s)} bir sonraki işleminde giriş ekranına döner.', confirmLabel: 'Oturumu kapat', danger: true);
    if (ok == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.revokeSession(s.id);
      toast('Oturum kapatıldı.');
      await _list.load(silent: true);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logoutAll() async {
    final ok = await confirmDialog(context,
        title: 'Tüm cihazlardan çıkılsın mı?', body: 'Bu telefon dahil bütün tarayıcı ve uygulama oturumları kapanır.', confirmLabel: 'Tüm cihazlardan çık', danger: true);
    if (ok == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.logoutAll();
    } catch (_) {
      // Sunucuya ulaşılamasa da bu cihazdaki oturum kapanır.
    }
    await ref.read(sessionProvider.notifier).dropLocal();
  }

  String _name(SessionView s) => (s.deviceName ?? '').isNotEmpty ? s.deviceName! : (s.kind == 'web' ? 'Tarayıcı' : 'Telefon');

  @override
  Widget build(BuildContext context) {
    final items = _list.data;
    return OpsPage(
      title: 'Cihazlarım',
      subtitle: 'Hesabınızın açık olduğu tarayıcı ve telefonlar',
      maxWidth: 720,
      onRefresh: () => _list.load(silent: true),
      children: [
        ListState(loading: _list.loading, hasData: items != null, count: items?.length ?? 0, error: _list.error, stale: _list.stale, onRetry: () => _list.load(), empty: 'Açık oturum yok.'),
        if (items == null && _list.loading) const CardSkeleton(count: 2),
        if (items != null)
          for (final s in items)
            Panel(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(10)),
                  child: Icon(s.kind == 'web' ? Icons.laptop_mac_outlined : (s.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android), size: 20, color: C.inkSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(_name(s), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if ((s.clientVersion ?? '').isNotEmpty) Text('v${s.clientVersion}', style: const TextStyle(color: C.muted, fontSize: 12)),
                      if (s.current) const Pill('Bu cihaz', tone: 'ok'),
                    ]),
                    const SizedBox(height: 3),
                    Text('Son görülme: ${s.lastSeenAt == null ? '—' : formatStamp(s.lastSeenAt)}', style: const TextStyle(color: C.muted, fontSize: 12.5)),
                  ]),
                ),
                if (!s.current)
                  TextButton(style: TextButton.styleFrom(foregroundColor: C.bad), onPressed: _busy ? null : () => _revoke(s), child: const Text('Oturumu kapat')),
              ]),
            ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: C.bad, side: const BorderSide(color: C.bad)),
          onPressed: _busy ? null : _logoutAll,
          child: const Text('Tüm cihazlardan çık'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Hesabı sil
class DeleteAccountSection extends ConsumerStatefulWidget {
  const DeleteAccountSection({super.key});
  @override
  ConsumerState<DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<DeleteAccountSection> {
  Future<void> _start() async {
    final due = await showDialog<String>(context: context, builder: (_) => const _DeleteDialog());
    if (due == null || !mounted) return;
    await ref.read(sessionProvider.notifier).dropLocal();
    toast(due.isEmpty ? 'Hesabınız silinmek üzere kapatıldı.' : 'Hesabınız ${formatDay(due)} tarihinde silinecek.');
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.badBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9B8B2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('İşletme hesabını sil', style: TextStyle(color: C.bad, fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 6),
          const Text(
            'Firma hemen kapanır, bütün hesapların oturumları kapanır, gönderilmemiş mesajlar iptal edilir. 30 gün içinde giriş ekranından geri alabilirsiniz; süre dolunca bütün kayıtlar kalıcı olarak silinir.',
            style: TextStyle(color: C.inkSoft, fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 12),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.bad), onPressed: _start, child: const Text('Hesabı sil')),
        ]),
      );
}

class _DeleteDialog extends ConsumerStatefulWidget {
  const _DeleteDialog();
  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  final _password = TextEditingController();
  final _typed = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!checkPassword(_password.text).ok) {
      setState(() => _error = 'Şifre girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).auth.requestDeletion(_password.text);
      if (mounted) Navigator.of(context).pop(res['deletionDueAt'] as String? ?? '');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = trUpper(_typed.text.trim()) == 'SİL';
    return AlertDialog(
      title: const Text('İşletme hesabı silinsin mi?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Firma hemen kapanır. 30 gün içinde giriş ekranından geri alabilirsiniz.', style: TextStyle(color: C.inkSoft)),
            const SizedBox(height: 14),
            AppField(label: 'Şifreniz', error: _error, child: PasswordInput(controller: _password, error: _error != null)),
            const Text.rich(TextSpan(children: [TextSpan(text: 'Onaylamak için '), TextSpan(text: 'SİL', style: TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: ' yazın')]),
                style: TextStyle(fontSize: 13, color: C.inkSoft)),
            const SizedBox(height: 6),
            TextField(controller: _typed, autocorrect: false, onChanged: (_) => setState(() {})),
          ]),
        ),
      ),
      actions: [
        OutlinedButton(autofocus: true, onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: C.bad), onPressed: ready && !_busy ? _submit : null, child: Text(_busy ? 'Gönderiliyor…' : 'Hesabı Sil')),
      ],
    );
  }
}
