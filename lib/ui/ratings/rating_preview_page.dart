import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../../core/session/session.dart';
import '../../core/theme/tokens.dart';
import '../../core/validation/validate.dart';

/// Müşterinin /r/:token'da göreceği ekranın önizlemesi. Sunucuya hiçbir şey yazmaz.
class RatingPreviewPage extends ConsumerStatefulWidget {
  const RatingPreviewPage({super.key});
  @override
  ConsumerState<RatingPreviewPage> createState() => _RatingPreviewPageState();
}

class _RatingPreviewPageState extends ConsumerState<RatingPreviewPage> {
  int _stars = 0;
  String _step = 'stars'; // stars | reasons | thanks | received
  final Set<String> _reasons = {};
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _stars = 0;
        _step = 'stars';
        _reasons.clear();
        _note.clear();
      });

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(sessionProvider.select((s) => s.me?.tenant?.name)) ?? 'İşletme';
    return Scaffold(
      backgroundColor: C.canvas,
      appBar: AppBar(
        title: const Text('Puan ekranı önizleme'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.canPop() ? context.pop() : context.go('/ops/degerlendirmeler')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.lift),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    color: C.side,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    child: Column(children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                        child: Text(trUpper(firm.isEmpty ? 'Y' : firm.characters.first), style: const TextStyle(color: C.goldInk, fontWeight: FontWeight.w700, fontSize: 19)),
                      ),
                      const SizedBox(height: 10),
                      Text(firm, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 3),
                      const Text('Sayın Ayşe Yılmaz', style: TextStyle(color: C.sideInk)),
                      const SizedBox(height: 3),
                      const Text('Fiş HK1001', style: TextStyle(color: C.gold, fontSize: 13.5)),
                    ]),
                  ),
                  Padding(padding: const EdgeInsets.all(22), child: _content()),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_step) {
      case 'thanks':
        return _done('Çok teşekkür ederiz!', "Birkaç kelimeyle Google'da yorum yazarsanız bize çok destek olursunuz. (Önizlemede Google'a gidilmez.)");
      case 'received':
        return _done('Teşekkürler', 'Geri bildiriminiz bize ulaştı. En kısa zamanda sizi arayacağız.');
      case 'reasons':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Üzgünüz, teşekkür ederiz', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(10)),
            child: const Text('Ne oldu? Birkaç kelime yazarsanız sizi arayıp sorunu çözelim.', style: TextStyle(color: C.inkSoft)),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (code, label) in feedbackReasons)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _reasons.contains(code) ? _reasons.remove(code) : _reasons.add(code)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _reasons.contains(code) ? C.ink : C.line, width: _reasons.contains(code) ? 1.5 : 1),
                  ),
                  child: Text(label, style: TextStyle(fontWeight: _reasons.contains(code) ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          const Text('Sorunu yazın (isteğe bağlı)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.inkSoft)),
          const SizedBox(height: 6),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: ratingNoteMax,
            decoration: const InputDecoration(hintText: 'Kısaca yazabilirsiniz'),
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => Text('$currentLength/$maxLength', style: const TextStyle(fontSize: 12, color: C.muted)),
          ),
          const SizedBox(height: 12),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => setState(() => _step = 'received'), child: const Text('Gönder')),
        ]);
      default:
        return Column(children: [
          const Text('Hizmetimizi puanlayın', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Bir yıldıza dokunmanız yeterli.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final cell = (box.maxWidth / 5).clamp(44.0, 64.0);
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var s = 1; s <= 5; s++)
                SizedBox(
                  width: cell,
                  height: 96,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _stars = s;
                      _step = s == 5 ? 'thanks' : 'reasons';
                    }),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedSlide(
                        offset: Offset(0, _stars == s ? -.04 : 0),
                        duration: const Duration(milliseconds: 120),
                        child: Icon(Icons.star_rounded, size: cell * .86, color: s <= _stars ? C.gold : C.line),
                      ),
                      Text(starCaptions[s]!, style: TextStyle(fontSize: 11, color: _stars == s ? C.ink : C.muted, fontWeight: _stars == s ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                ),
            ]);
          }),
        ]);
    }
  }

  Widget _done(String title, String body) => Column(children: [
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: C.inkSoft, height: 1.45)),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: _reset, child: const Text('Baştan Başla')),
      ]);
}
