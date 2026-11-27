import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/session/session.dart';
import '../../core/validation/validate.dart';
import '../widgets/common.dart';
import 'gate.dart';

const _notices = {
  LoginNotice.registered: 'Başvurunuz alındı. Onaylandığında bu ekrandan giriş yapabilirsiniz.',
  LoginNotice.expired: 'Oturumunuz sona erdi. Kaldığınız sayfaya dönmek için yeniden giriş yapın.',
  LoginNotice.idle: 'Uzun süre işlem yapılmadığı için oturum kapatıldı.',
  LoginNotice.passwordChanged: 'Şifreniz değişti. Yeni şifrenizle giriş yapın.',
};

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  Map<String, String> _errors = {};
  String? _error;
  String? _info;
  bool _busy = false;
  int _wait = 0;
  Timer? _countdown;

  /// Firma kapanıyor (tenant_closing) → sahibi silme talebini geri alabilir.
  bool _closing = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _countdown?.cancel();
    super.dispose();
  }

  void _startWait(int seconds) {
    _countdown?.cancel();
    setState(() {
      _wait = seconds;
      _error = 'Çok fazla deneme yapıldı. $seconds saniye sonra yeniden deneyin.';
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) {
        t.cancel();
        setState(() => _error = null);
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _wait > 0) return;
    final checks = runChecks({'phone': () => checkPhone(_phone.text), 'password': () => checkPassword(_password.text)});
    setState(() {
      _errors = checks.errors;
      _error = null;
      _info = null;
    });
    if (!checks.valid) return;
    setState(() => _busy = true);
    final session = ref.read(sessionProvider);
    final from = session.from;
    try {
      await ref.read(sessionProvider.notifier).signIn(_phone.text.trim(), _password.text);
      if (!mounted) return;
      context.go(from != null && from.startsWith('/ops') ? from : '/ops');
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 429) {
        final s = e.extra['retryAfterSeconds'];
        _startWait(s is num && s > 0 ? s.toInt() : 60);
      } else if (e.code == 'tenant_closing') {
        setState(() {
          _closing = true;
          _error = e.message;
        });
      } else if (e.status == 426) {
        // Oturum denetleyicisi güncelleme ekranına geçer.
      } else {
        final field = e.code == 'invalid_credentials' ? null : fieldOfError(e);
        setState(() {
          if (field == 'phone' || field == 'password') {
            _errors = {field!: e.message};
          } else {
            _error = e.message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    final phone = checkPhone(_phone.text);
    final password = checkPassword(_password.text);
    if (!phone.ok || !password.ok) {
      setState(() => _errors = {if (!phone.ok) 'phone': phone.error!, if (!password.ok) 'password': password.error!});
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.cancelDeletion(phone.value!, _password.text);
      if (!mounted) return;
      setState(() {
        _closing = false;
        _error = null;
        _info = 'Silme talebiniz geri alındı. Şimdi giriş yapabilirsiniz.';
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = _info ?? _notices[ref.watch(sessionProvider.select((s) => s.notice))];
    return GateLayout(
      title: 'Hoş geldiniz',
      lead: 'Telefon numaranız ve şifrenizle giriş yapın.',
      error: _error,
      notice: _error == null ? notice : null,
      footer: LinkText(lead: 'Hesabınız yok mu?', link: 'İşletmenizi kaydedin', onTap: () => context.go('/register')),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppField(
            label: 'Cep Telefonu',
            error: _errors['phone'],
            child: PhoneInput(
              controller: _phone,
              error: _errors.containsKey('phone'),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _errors.remove('phone')),
            ),
          ),
          AppField(
            label: 'Şifre',
            error: _errors['password'],
            child: PasswordInput(
              controller: _password,
              error: _errors.containsKey('password'),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _errors.remove('password')),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _busy || _wait > 0 ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_wait > 0 ? 'Bekleyin ($_wait sn)' : (_busy ? 'Giriş yapılıyor…' : 'Giriş yap')),
          ),
          if (_closing) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _cancelDeletion,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Silme talebini geri al'),
            ),
          ],
        ]),
      ),
    );
  }
}
