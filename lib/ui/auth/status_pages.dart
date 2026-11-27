import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';
import '../widgets/common.dart';
import 'gate.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: C.side,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Brand(dark: true, size: 44),
            SizedBox(height: 28),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.gold)),
          ]),
        ),
      );
}

class BlockedPage extends ConsumerStatefulWidget {
  const BlockedPage({super.key});
  @override
  ConsumerState<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends ConsumerState<BlockedPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showCancel = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final phone = checkPhone(_phone.text);
    if (!phone.ok || !checkPassword(_password.text).ok) {
      setState(() => _error = phone.error ?? 'Şifre girin.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).auth.cancelDeletion(phone.value!, _password.text);
      await ref.read(sessionProvider.notifier).signOut();
      if (mounted) toast('Silme talebiniz geri alındı. Yeniden giriş yapın.');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = ref.watch(sessionProvider.select((s) => s.block));
    final code = block?.code ?? '';
    final title = switch (code) {
      'tenant_pending' => 'Başvurunuz onay bekliyor',
      'tenant_rejected' => 'Başvurunuz onaylanmadı',
      'tenant_suspended' => 'İşletme hesabınız askıya alınmıştır.',
      _ => 'Hesap kapalı',
    };
    final message = (block?.message ?? '').isEmpty ? 'Lütfen platform yönetimiyle iletişime geçin.' : block!.message;
    return GateLayout(
      title: title,
      lead: message,
      error: _error,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (code == 'tenant_closing') ...[
          if (!_showCancel)
            OutlinedButton(onPressed: () => setState(() => _showCancel = true), child: const Text('Silme talebini geri al'))
          else ...[
            AppField(label: 'Cep Telefonu', child: PhoneInput(controller: _phone)),
            AppField(label: 'Şifre', child: PasswordInput(controller: _password)),
            OutlinedButton(onPressed: _busy ? null : _cancel, child: Text(_busy ? 'Gönderiliyor…' : 'Silme talebini geri al')),
          ],
          const SizedBox(height: 10),
        ],
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () async {
            await ref.read(sessionProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
          child: const Text('Giriş ekranına dön'),
        ),
      ]),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) => GateLayout(
        title: 'Sayfa bulunamadı',
        lead: 'Aradığınız adres bu uygulamada yok.',
        child: FilledButton(onPressed: () => context.go('/ops'), child: const Text('Ana sayfaya dön')),
      );
}

class UpdatePage extends ConsumerWidget {
  const UpdatePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(sessionProvider.select((s) => s.updateUrl));
    return PopScope(
      canPop: false,
      child: GateLayout(
        title: 'Uygulamanın yeni sürümünü yükleyin.',
        lead: 'Devam etmek için güncelleyin.',
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: url == null || url.isEmpty ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: const Text('Güncelle'),
        ),
      ),
    );
  }
}

/// Beklenmeyen hata ekranı (ErrorBoundary karşılığı).
class CrashView extends StatelessWidget {
  const CrashView({super.key, this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Panel(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Bu ekran açılamadı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Beklenmeyen bir hata oldu. Girdiğiniz veriler kaydedilmediyse yeniden yazmanız gerekebilir.',
                  textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
              if (onRetry != null) ...[const SizedBox(height: 14), FilledButton(onPressed: onRetry, child: const Text('Tekrar dene'))],
            ]),
          ),
        ),
      );
}

String apiMessage(Object e) => e is ApiError ? e.message : 'İşlem yapılamadı.';
