import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/session/session.dart';
import '../../core/validation/validate.dart';
import '../widgets/common.dart';
import 'gate.dart';

/// Kayıt ve ekip formlarının ortak alanları.
class NewAccountControllers {
  final business = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final repeat = TextEditingController();

  List<TextEditingController> get all => [business, name, phone, password, repeat];
  bool get dirty => all.any((c) => c.text.isNotEmpty);

  CheckResult check() => runChecks({
        'business': () => checkBrandName(business.text),
        'name': () => checkPersonName(name.text),
        'phone': () => checkPhone(phone.text),
        'password': () => checkNewPassword(password.text, phone.text),
        'repeat': () => checkPasswordRepeat(password.text, repeat.text),
      });

  void clear() {
    for (final c in all) {
      c.clear();
    }
  }

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

class NewAccountFields extends StatelessWidget {
  const NewAccountFields({super.key, required this.c, required this.errors, required this.onEdit});
  final NewAccountControllers c;
  final Map<String, String> errors;
  final void Function(String key) onEdit;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppField(
          label: 'İşletme / Marka Adı',
          error: errors['business'],
          child: TextField(controller: c.business, maxLength: nameMax, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: fieldDecoration(error: errors.containsKey('business')), onChanged: (_) => onEdit('business')),
        ),
        AppField(
          label: 'Yetkili Adı Soyadı',
          error: errors['name'],
          child: TextField(controller: c.name, maxLength: nameMax, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.name], decoration: fieldDecoration(error: errors.containsKey('name')), onChanged: (_) => onEdit('name')),
        ),
        AppField(
          label: 'Cep Telefonu',
          error: errors['phone'],
          child: PhoneInput(controller: c.phone, error: errors.containsKey('phone'), textInputAction: TextInputAction.next, onChanged: (_) => onEdit('phone')),
        ),
        AppField(
          label: 'Şifre',
          error: errors['password'],
          hint: 'En az 8 karakter; en az bir harf ve bir rakam.',
          child: PasswordInput(controller: c.password, strength: true, newPassword: true, error: errors.containsKey('password'), onChanged: (_) => onEdit('password')),
        ),
        AppField(
          label: 'Şifre (tekrar)',
          error: errors['repeat'],
          child: PasswordInput(controller: c.repeat, newPassword: true, error: errors.containsKey('repeat'), onChanged: (_) => onEdit('repeat')),
        ),
      ]);
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _c = NewAccountControllers();
  Map<String, String> _errors = {};
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final checks = _c.check();
    setState(() {
      _errors = checks.errors;
      _error = null;
    });
    if (!checks.valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.register(
            business: checks.values['business'] as String,
            name: checks.values['name'] as String,
            phone: checks.values['phone'] as String,
            password: _c.password.text,
          );
      _c.clear();
      ref.read(sessionProvider.notifier).setNotice(LoginNotice.registered);
      if (mounted) context.go('/login');
    } on ApiError catch (e) {
      final field = fieldOfError(e);
      if (!mounted) return;
      setState(() {
        if (field != null && const ['business', 'name', 'phone', 'password'].contains(field)) {
          _errors = {field: e.message};
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_c.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) context.go('/login');
      },
      child: GateLayout(
        title: 'İşletmenizi kaydedin',
        lead: 'Başvurunuzu inceleyip kısa sürede hesabınızı açıyoruz.',
        error: _error,
        footer: LinkText(lead: 'Hesabınız var mı?', link: 'Giriş yapın', onTap: () => context.go('/login')),
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            NewAccountFields(c: _c, errors: _errors, onEdit: (k) => setState(() => _errors.remove(k))),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_busy ? 'Gönderiliyor…' : 'Başvuruyu Gönder'),
            ),
          ]),
        ),
      ),
    );
  }
}
