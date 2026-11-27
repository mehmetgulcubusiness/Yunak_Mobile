import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../widgets/common.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false, this.name = 'Yunak', this.size = 34});
  final bool dark;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(9)),
          child: AppIcon('mark', size: size * .6, color: C.goldInk),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dark ? Colors.white : C.ink, letterSpacing: -.2)),
        ),
      ]);
}

/// Giriş/kayıt ortak çerçevesi. Geniş ekranda solda koyu tanıtım paneli.
class GateLayout extends StatelessWidget {
  const GateLayout({super.key, required this.title, this.lead, this.error, this.notice, required this.child, this.footer});
  final String title;
  final String? lead;
  final String? error;
  final String? notice;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Align(alignment: Alignment.centerLeft, child: Brand(size: 30)),
        const SizedBox(height: 28),
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.5)),
        if (lead != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(lead!, style: const TextStyle(color: C.muted, fontSize: 14.5, height: 1.45))),
        const SizedBox(height: 22),
        if (error != null) Semantics(liveRegion: true, child: Notice(error!)),
        if (notice != null) Notice(notice!, tone: 'ok'),
        child,
        if (footer != null) Padding(padding: const EdgeInsets.only(top: 18), child: Center(child: footer!)),
      ]),
    );
    return Scaffold(
      backgroundColor: C.surface,
      body: LayoutBuilder(builder: (context, box) {
        final form = SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: box.maxWidth > Bp.phone ? 40 : 22, vertical: 28),
              child: card,
            ),
          ),
        );
        if (box.maxWidth <= Bp.wide) return form;
        return Row(children: [const Expanded(child: _Story()), Expanded(child: form)]);
      }),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story();

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white);
    return Container(
      color: C.side,
      padding: const EdgeInsets.all(48),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Brand(dark: true),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.side2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF27272A))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (final (k, v, gold) in const [('Açık iş', '8', false), ('Yıkamada', '4', false), ('Bugünkü ciro', '5.600 ₺', true)])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.side, borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (gold) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle)),
                          Text(k, style: const TextStyle(color: C.sideInk, fontSize: 11.5)),
                        ]),
                        const SizedBox(height: 4),
                        Text(v, style: white.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              for (final (name, svc, step, amount) in const [
                ('Ayşe Yılmaz', 'Halı Yıkama · #HK1001', 1, '3.250 ₺'),
                ('Mustafa Çelik', 'Koltuk Yıkama · #HK1002', 2, '2.100 ₺'),
              ])
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.side, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: white.copyWith(fontWeight: FontWeight.w600)),
                        Text(svc, style: const TextStyle(color: C.sideInk, fontSize: 12)),
                      ]),
                    ),
                    Text('adım $step/3', style: const TextStyle(color: C.sideInk, fontSize: 12)),
                    const SizedBox(width: 14),
                    Text(amount, style: white.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _bubble('✓ Müşteriye WhatsApp\'tan haber gitti'),
                _bubble('★★★★★ Yeni yorum', gold: true),
              ]),
            ]),
          ),
          const SizedBox(height: 36),
          Text('Halı yıkama işinizi tek ekrandan yönetin.', style: white.copyWith(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -.6)),
          const SizedBox(height: 18),
          for (final line in const [
            'Fişi saniyeler içinde açın',
            'Müşteriye WhatsApp\'tan otomatik haber gitsin',
            'Şikâyeti ilk siz duyun, kasanızı tek ekranda görün',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const AppIcon('check', size: 16, color: C.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(line, style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 14.5))),
              ]),
            ),
          const Spacer(),
          const Text('Halı, koltuk, yorgan ve perde yıkama için · WhatsApp ile çalışır', style: TextStyle(color: C.sideInk, fontSize: 12.5)),
        ]),
      ),
    );
  }

  Widget _bubble(String text, {bool gold = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: gold ? C.gold : const Color(0xFF14532D), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: gold ? C.goldInk : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}

class LinkText extends StatelessWidget {
  const LinkText({super.key, required this.lead, required this.link, required this.onTap});
  final String lead;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(lead, style: const TextStyle(color: C.muted, fontSize: 14)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 36)),
          child: Text(link, style: const TextStyle(decoration: TextDecoration.underline)),
        ),
      ]);
}
