import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api/api_error.dart';
import '../../core/format/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';

// ------------------------------------------------------------------ İkon
/// `assets/icons/<name>.svg` (web'deki Icon.jsx'ten üretildi; çizgi ikon, 24×24).
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 18, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? C.ink;
    return SvgPicture.asset('assets/icons/$name.svg', width: size, height: size, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
  }
}

// ---------------------------------------------------------------- Toast
enum ToastTone { good, bad }

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String message, {ToastTone tone = ToastTone.good}) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  final good = tone == ToastTone.good;
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: Duration(milliseconds: good ? 3800 : 6000),
    backgroundColor: good ? C.ink : C.bad,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    showCloseIcon: true,
    closeIconColor: Colors.white70,
    content: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: good ? const Color(0xFF4ADE80) : Colors.white)),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
    ]),
  ));
}

void toastError(Object e, [String fallback = 'İşlem yapılamadı.']) => toast(errorText(e, fallback), tone: ToastTone.bad);

String errorText(Object? e, [String fallback = 'İşlem yapılamadı.']) => e is ApiError ? e.message : fallback;

// --------------------------------------------------------------- Field
class AppField extends StatelessWidget {
  const AppField({super.key, required this.label, required this.child, this.error, this.hint, this.note, this.after});
  final String label;
  final Widget child;
  final String? error;
  final String? hint;
  final Widget? note;
  final Widget? after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.inkSoft)),
        const SizedBox(height: 6),
        child,
        ?after,
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(error!, style: const TextStyle(color: C.bad, fontSize: 12.5))),
          ),
        if (hint != null)
          Padding(padding: const EdgeInsets.only(top: 5), child: Text(hint!, style: const TextStyle(color: C.muted, fontSize: 12.5))),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 6), child: note!),
      ]),
    );
  }
}

InputDecoration fieldDecoration({String? hint, bool error = false, Widget? suffix, Widget? prefix}) => InputDecoration(
      hintText: hint,
      counterText: '',
      suffixIcon: suffix,
      prefixIcon: prefix,
      enabledBorder: error
          ? OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.bad))
          : null,
    );

class _FnFormatter extends TextInputFormatter {
  _FnFormatter(this.fn);
  final String Function(String) fn;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = fn(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

TextInputFormatter fnFormatter(String Function(String) fn) => _FnFormatter(fn);

class PhoneInput extends StatelessWidget {
  const PhoneInput({super.key, required this.controller, this.error = false, this.onChanged, this.focusNode, this.autofocus = false, this.textInputAction});
  final TextEditingController controller;
  final bool error;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        maxLength: phoneMaskLength,
        autofillHints: const [AutofillHints.telephoneNumber, AutofillHints.username],
        inputFormatters: [fnFormatter(maskPhone)],
        style: const TextStyle(fontFeatures: tabular),
        decoration: fieldDecoration(hint: '05xx xxx xx xx', error: error),
        onChanged: onChanged,
      );
}

class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    required this.controller,
    this.error = false,
    this.onChanged,
    this.strength = false,
    this.newPassword = false,
    this.onSubmitted,
    this.textInputAction,
  });
  final TextEditingController controller;
  final bool error;
  final ValueChanged<String>? onChanged;
  final bool strength;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: passwordMaxBytes,
      textInputAction: widget.textInputAction,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: fieldDecoration(
        error: widget.error,
        suffix: TextButton(
          onPressed: () => setState(() => _show = !_show),
          child: Text(_show ? 'Gizle' : 'Göster', style: const TextStyle(fontSize: 13)),
        ),
      ),
      onChanged: (v) {
        widget.onChanged?.call(v);
        if (widget.strength) setState(() {});
      },
      onSubmitted: widget.onSubmitted,
    );
    if (!widget.strength) return field;
    final s = passwordStrength(widget.controller.text);
    final color = s.score <= 1 ? C.bad : (s.score == 2 ? C.gold : C.ok);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      field,
      if (widget.controller.text.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(color: i < s.score ? color : C.chip, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text('Şifre gücü: ${s.label}', style: const TextStyle(fontSize: 12, color: C.muted)),
      ],
    ]);
  }
}

/// Tutar kutusu: odaktan çıkınca "1.250,00" biçimine geçer.
class AmountInput extends StatefulWidget {
  const AmountInput({super.key, required this.controller, this.error = false, this.onChanged, this.onBlur, this.hint = '0,00'});
  final TextEditingController controller;
  final bool error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<Check<double>>? onBlur;
  final String hint;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      final o = parseAmount(widget.controller.text);
      if (o.ok && o.value != null) widget.controller.text = formatAmount(o.value);
      widget.onBlur?.call(o);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [fnFormatter(filterAmount)],
        style: const TextStyle(fontFeatures: tabular),
        decoration: fieldDecoration(hint: widget.hint, error: widget.error, suffix: const Padding(padding: EdgeInsets.all(12), child: Text('₺', style: TextStyle(color: C.muted)))),
        onChanged: widget.onChanged,
      );
}

/// "Bu tutar ₺1.250,00 olarak kaydedilecek."
String? amountPreview(String text) {
  final o = parseAmount(text);
  if (!o.ok || o.value == null) return null;
  return 'Bu tutar ₺${formatAmount(o.value)} olarak kaydedilecek.';
}

// ------------------------------------------------------------- Kutular
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.tone = 'bad', this.action});
  final String text;
  final String tone; // bad | ok | warn
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) { 'ok' => (C.okBg, C.ok), 'warn' => (C.warnBg, C.warn), _ => (C.badBg, C.bad) };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w500))),
        if (action != null) ...[const SizedBox(width: 10), action!],
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.margin = const EdgeInsets.only(bottom: 14), this.dark = false});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: dark ? C.side : C.surface,
          borderRadius: BorderRadius.circular(14),
          border: dark ? null : Border.all(color: C.line),
          boxShadow: dark ? Shadows.darkKpi : Shadows.card,
        ),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.sub, this.trailing});
  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: const TextStyle(fontSize: 13, color: C.muted))),
            ]),
          ),
          ?trailing,
        ]),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = 'plain'});
  final String text;
  final String tone; // plain ok bad wait muted gold

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      'ok' => (C.okBg, C.ok, null),
      'bad' => (C.badBg, C.bad, null),
      'wait' => (C.warnBg, C.warn, null),
      'muted' => (C.chip, C.muted, null),
      'gold' => (const Color(0xFFF6EEDC), C.goldInk, C.gold),
      _ => (C.surface, C.inkSoft, C.line),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: border == null ? null : Border.all(color: border)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class Ping extends StatelessWidget {
  const Ping(this.count, {super.key});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.bad, borderRadius: BorderRadius.circular(9)),
        child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class Monogram extends StatelessWidget {
  const Monogram(this.name, {super.key, this.size = 36, this.dark = false});
  final String name;
  final double size;
  final bool dark;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return trUpper(parts.map((p) => p.characters.first).join());
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: dark ? C.side2 : C.chip, borderRadius: BorderRadius.circular(size / 2), border: Border.all(color: dark ? C.side2 : C.line)),
        child: Text(initials(name), style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w600, color: dark ? Colors.white : C.ink)),
      );
}

/// Segment sekmeler: seçili siyah, sayaç altın.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String, int?)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            for (final (v, label, count) in items)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Material(
                  color: v == value ? C.action : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onChanged(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: v == value ? Colors.white : C.inkSoft)),
                        if (count != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: v == value ? C.gold : C.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: v == value ? null : Border.all(color: C.line),
                            ),
                            child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: v == value ? C.goldInk : C.inkSoft, fontFeatures: tabular)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ----------------------------------------------------------- Liste durumu
class ListState extends StatelessWidget {
  const ListState({
    super.key,
    required this.loading,
    required this.hasData,
    required this.count,
    this.error,
    this.stale = false,
    this.onRetry,
    this.query = '',
    this.empty = 'Kayıt yok.',
    this.searchEmpty,
  });
  final bool loading;
  final bool hasData;
  final int count;
  final Object? error;
  final bool stale;
  final VoidCallback? onRetry;
  final String query;
  final String empty;
  final String? searchEmpty;

  @override
  Widget build(BuildContext context) {
    if (error != null && !hasData) {
      return Notice(errorText(error, 'Liste yüklenemedi.'), action: onRetry == null ? null : _SmallButton('Yeniden dene', onRetry!));
    }
    if (stale && hasData) {
      return Notice('Liste güncellenemedi. Gösterilen bilgiler eski olabilir.', tone: 'warn', action: onRetry == null ? null : _SmallButton('Yenile', onRetry!));
    }
    if (!loading && hasData && count == 0) {
      return Panel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: Column(children: [
          Text(query.isNotEmpty ? (searchEmpty ?? 'Aramayla eşleşen kayıt yok.') : empty,
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
          if (query.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Farklı bir ad, telefon veya fiş numarası deneyin.', textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13)),
            ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < count; i++)
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bar(160),
              const SizedBox(height: 10),
              _bar(240),
              const SizedBox(height: 10),
              _bar(100),
            ]),
          ),
      ]);
  Widget _bar(double w) => Container(width: w, height: 12, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(6)));
}

// ----------------------------------------------------------------- Pager
const pageSize = 50;

class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.total, required this.onPage, this.noun = 'kayıt', this.nounFrom = 'kayıttan'});
  final int page;
  final int total;
  final ValueChanged<int> onPage;
  final String noun;
  final String nounFrom;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final pages = (total / pageSize).ceil().clamp(1, 1 << 30);
    const style = TextStyle(color: C.muted, fontSize: 13);
    if (pages == 1) return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Toplam $total $noun gösteriliyor', style: style, textAlign: TextAlign.center));
    final from = (page - 1) * pageSize + 1;
    final to = (page * pageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text('Toplam $total $nounFrom $from–$to arası gösteriliyor', style: style, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: page > 1 ? () => onPage(page - 1) : null, child: const Text('← Önceki')),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('Sayfa $page / $pages', style: const TextStyle(fontWeight: FontWeight.w500))),
          OutlinedButton(onPressed: page < pages ? () => onPage(page + 1) : null, child: const Text('Sonraki →')),
        ]),
      ]),
    );
  }
}

// --------------------------------------------------------------- Stepper
class StageBadge extends StatelessWidget {
  const StageBadge({super.key, required this.status, required this.serviceType, this.wide = false});
  final String status;
  final String serviceType;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final sofa = serviceType == 'sofa_wash';
    final (step, label, tone, pct) = switch (status) {
      'received' || 'scheduled' => (1, sofa ? 'Randevulu' : 'Teslim alındı', 'start', .40),
      'washing' || 'in_progress' => (2, sofa ? 'İşlemde' : 'Yıkamada', 'mid', .75),
      'delivered' || 'completed' => (3, sofa ? 'Bitti' : 'Teslim edildi', 'done', 1.0),
      _ => (0, 'Randevu bekliyor', 'wait', .10),
    };
    final (bg, fg, bar) = switch (tone) {
      'start' => (C.chip, C.ink, C.ink),
      'mid' => (C.midBg, C.midInk, C.midBar),
      'done' => (C.okBg, C.ok, C.ok),
      _ => (C.surface, C.muted, C.lineStrong),
    };
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: tone == 'wait' ? Border.all(color: C.line) : null),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tone == 'wait' ? null : fg, border: tone == 'wait' ? Border.all(color: C.stone, width: 1.5) : null),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        if (step > 0) Text('  $step/3', style: TextStyle(fontSize: 12, color: fg.withValues(alpha: .7), fontFeatures: tabular)),
      ]),
    );
    return Semantics(
      label: 'İşin durumu: $label${step > 0 ? ', $step/3' : ''}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        badge,
        const SizedBox(height: 6),
        SizedBox(
          width: wide ? double.infinity : 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: C.chip, valueColor: AlwaysStoppedAnimation(bar)),
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ Onay penceresi
class NoteSpec {
  const NoteSpec({required this.label, this.max = 300, this.initial = ''});
  final String label;
  final int max;
  final String initial;
}

class ConfirmResult {
  const ConfirmResult(this.note);
  final String note;
}

String _normalizeConfirm(String s) => trUpper(s.trim().replaceAll(RegExp(r'\s+'), ' '));

Future<ConfirmResult?> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  List<String>? items,
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  bool danger = false,
  String? typeToConfirm,
  NoteSpec? note,
}) {
  return showDialog<ConfirmResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ConfirmDialog(
      title: title,
      body: body,
      items: items,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      danger: danger,
      typeToConfirm: typeToConfirm,
      note: note,
    ),
  );
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.title, this.body, this.items, required this.confirmLabel, required this.cancelLabel, required this.danger, this.typeToConfirm, this.note});
  final String title;
  final String? body;
  final List<String>? items;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final String? typeToConfirm;
  final NoteSpec? note;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late final _note = TextEditingController(text: widget.note?.initial ?? '');
  final _typed = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _typed.dispose();
    super.dispose();
  }

  bool get _canConfirm => widget.typeToConfirm == null || _normalizeConfirm(_typed.text) == _normalizeConfirm(widget.typeToConfirm!);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (widget.body != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.body!, style: const TextStyle(color: C.inkSoft, fontSize: 14, height: 1.45))),
            if (widget.items != null && widget.items!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final item in widget.items!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('•  ', style: TextStyle(color: C.muted)),
                        Expanded(child: Text(item, style: const TextStyle(fontSize: 13.5, color: C.inkSoft))),
                      ]),
                    ),
                ]),
              ),
            if (widget.note != null) ...[
              const SizedBox(height: 14),
              AppField(
                label: widget.note!.label,
                child: TextField(
                  controller: _note,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: widget.note!.max,
                  decoration: const InputDecoration(),
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      Text('$currentLength/$maxLength', style: const TextStyle(fontSize: 12, color: C.muted)),
                ),
              ),
            ],
            if (widget.typeToConfirm != null) ...[
              const SizedBox(height: 14),
              Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: C.inkSoft), children: [
                const TextSpan(text: 'Onaylamak için '),
                TextSpan(text: widget.typeToConfirm, style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink)),
                const TextSpan(text: ' yazın'),
              ])),
              const SizedBox(height: 6),
              TextField(controller: _typed, autofocus: widget.note == null, autocorrect: false, onChanged: (_) => setState(() {})),
            ],
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(autofocus: widget.note == null && widget.typeToConfirm == null, onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel)),
              const SizedBox(width: 10),
              FilledButton(
                style: widget.danger ? FilledButton.styleFrom(backgroundColor: C.bad) : null,
                onPressed: _canConfirm ? () => Navigator.pop(context, ConfirmResult(_note.text.trim())) : null,
                child: Text(widget.confirmLabel),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Kaydedilmemiş değişiklik koruması.
Future<bool> confirmDiscard(BuildContext context) async =>
    await confirmDialog(context, title: 'Kaydedilmemiş değişiklikler var. Çıkılsın mı?', confirmLabel: 'Çık', cancelLabel: 'Kal', danger: true) != null;

// ---------------------------------------------------------- Menü (⋯)
class MoreItem {
  const MoreItem(this.label, this.onTap, {this.danger = false, this.icon});
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final String? icon;
}

class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, required this.items, this.disabled = false});
  final List<MoreItem> items;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Diğer işlemler',
      onPressed: disabled || items.isEmpty
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final item in items)
                      ListTile(
                        leading: item.icon == null ? null : AppIcon(item.icon!, color: item.danger ? C.bad : C.inkSoft),
                        title: Text(item.label, style: TextStyle(color: item.danger ? C.bad : C.ink, fontWeight: FontWeight.w500)),
                        onTap: () {
                          Navigator.pop(ctx);
                          item.onTap();
                        },
                      ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
      icon: const Text('⋯', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.inkSoft)),
    );
  }
}

// --------------------------------------------------- Otomatik yenileme
/// Ön plandayken her [interval]'de bir; ön plana dönünce (son yenilemeden 5 sn geçtiyse) de çağırır.
class AutoRefresh with WidgetsBindingObserver {
  AutoRefresh(this.interval, this.onTick) {
    WidgetsBinding.instance.addObserver(this);
    _start();
  }
  final Duration interval;
  final VoidCallback onTick;
  Timer? _timer;
  DateTime _last = DateTime.now();

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _fire());
  }

  void _fire() {
    _last = DateTime.now();
    onTick();
  }

  void touched() => _last = DateTime.now();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_last) > const Duration(seconds: 5)) _fire();
      _start();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
