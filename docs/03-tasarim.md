# 03 — Tasarım sistemi

Kaynak: `src/styles/base.css` (bütün renkler), `ops.css` (panel), `gate.css` (giriş), `rating.css` (puan), `analytics.css`.

**Tasarım dili: "sessiz lüks".** Monokrom yüzeyler, tek vurgu rengi (mat şampanya altını `#C5A059`), tek ana aksiyon rengi (mat siyah `#18181B`). Yeşil ve kırmızı **yalnız durum** bildirir; süs için renk kullanılmaz. Tema yalnız açık (light); koyu tema yok.

## 1. Renk tokenları

```dart
// lib/core/theme/tokens.dart
abstract final class C {
  // Yüzeyler
  static const canvas    = Color(0xFFF4F4F6); // sayfa zemini
  static const chip      = Color(0xFFF4F4F5); // segment/çip zemini, boş çubuk
  static const surface   = Color(0xFFFFFFFF); // kart
  static const sunk      = Color(0xFFFAFAFA); // içe gömük alan, kapalı iş satırı
  static const line      = Color(0xFFE4E4E7); // kenarlık
  static const lineSoft  = Color(0xFFF4F4F5); // satır ayırıcı
  static const lineStrong= Color(0xFFD4D4D8);
  static const stone     = Color(0xFFA1A1AA);

  // Yazı
  static const ink       = Color(0xFF09090B); // ana metin
  static const inkSoft   = Color(0xFF52525B); // ikincil metin
  static const muted     = Color(0xFF71717A); // ipucu, etiket

  // Yan menü (koyu)
  static const side      = Color(0xFF09090B);
  static const side2     = Color(0xFF18181B);
  static const sideInk   = Color(0xFFA1A1AA);

  // Aksiyon ve vurgu
  static const action      = Color(0xFF18181B); // birincil düğme
  static const actionHover = Color(0xFF27272A);
  static const gold        = Color(0xFFC5A059); // tek vurgu
  static const goldHover   = Color(0xFFB08D48);
  static const goldInk     = Color(0xFF1C1608); // altın üstündeki yazı
  static const ring        = Color(0x1F09090B); // odak halkası (%12)

  // Durum
  static const ok     = Color(0xFF166534); static const okBg   = Color(0xFFEDF5EF);
  static const warn   = Color(0xFF7A5A1E); static const warnBg = Color(0xFFF7F1E4);
  static const bad    = Color(0xFF9F2A20); static const badBg  = Color(0xFFF8EBE9);

  // İş aşaması (Stepper) ek renkleri
  static const midBg   = Color(0xFFFEF3C7); static const midInk = Color(0xFF92400E); // "Yıkamada"
  static const midBar  = Color(0xFF10B981);
  static const undoBg  = Color(0xFFFFFBEB);                                     // "Geri al" düğmesi
}
```

### Gölge ve köşe

| Token | Değer | Flutter |
| --- | --- | --- |
| `--radius` | 12 | `BorderRadius.circular(12)` (genel) |
| Kart (KPI, board) | 16 (telefonda 14) | |
| Düğme | 8 | |
| Çip / pill / todo | 99 (tam yuvarlak) | `StadiumBorder()` |
| `--shadow-card` | `0 4px 20px -2px rgba(9,9,11,.05)` | `BoxShadow(color: Color(0x0D09090B), blurRadius: 20, offset: Offset(0,4), spreadRadius: -2)` |
| `--shadow-lift` | `0 10px 24px -4px rgba(9,9,11,.1)` | |
| `--shadow-lg` | `0 24px 56px -20px rgba(0,0,0,.3)` | menü/modal |

## 2. Tipografi

- Font: **Inter** 400/500/600/700, `assets/fonts/` içinden (ağdan font çekilmez).
- Bütün rakamlar **tabular** (`FontFeature.tabularFigures()`); tutar, telefon, fiş no, KPI'da harf aralığı `-0.02em` (≈ `letterSpacing: -0.3`).

| Kullanım | Boyut / ağırlık | Not |
| --- | --- | --- |
| Sayfa başlığı (`.page-head h1`) | 24 / 600 (telefonda 22) | `letterSpacing -0.5` |
| Selam (`.hello h1`) | 22 / 700 (telefonda 20) | "Günaydın, Ayşe" |
| KPI rakamı | 30 / 700 (telefonda 24) | |
| KPI etiketi | 11.5 / 600, BÜYÜK HARF, `letterSpacing 0.7` | `muted` |
| Müşteri adı (iş kartı) | 15 / 600 | |
| Gövde | 14 / 400–500 | |
| İkincil satır (`.line2`) | 13 (telefonda 12.5) | `inkSoft` |
| İpucu (`.hint`) | 13 | `muted` |
| Tutar | 16 / 700 | |
| Pill / rozet | 12 / 500 | |
| Segment sekme | 13.5 / 600 | |
| Tablo başlığı | 11 / 600 BÜYÜK HARF `letterSpacing .7` | |

```dart
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: C.canvas,
  colorScheme: const ColorScheme.light(
    primary: C.action, onPrimary: Colors.white,
    secondary: C.gold, onSecondary: C.goldInk,
    surface: C.surface, onSurface: C.ink,
    error: C.bad, onError: Colors.white,
    outline: C.line,
  ),
  dividerColor: C.lineSoft,
  textTheme: const TextTheme(/* tabloya göre */),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    backgroundColor: C.action, foregroundColor: Colors.white, minimumSize: const Size(0, 44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontWeight: FontWeight.w600))),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
    foregroundColor: C.ink, backgroundColor: C.surface, side: const BorderSide(color: C.line),
    minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: C.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.line)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.ink, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: C.bad)),
    errorStyle: const TextStyle(color: C.bad, fontSize: 12.5),
    helperStyle: const TextStyle(color: C.muted, fontSize: 12.5),
  ),
);
```

## 3. Düğme türleri

| CSS sınıfı | Görünüm | Kullanım |
| --- | --- | --- |
| `.btn` | Beyaz zemin, `line` kenar, 40 yük., 8 köşe | İkincil |
| `.btn.primary` | Siyah (`action`) zemin, beyaz yazı | Ana işlem (Fişi Oluştur, Kaydet, Yıkamaya Al →) |
| `.btn.gold` | Altın zemin, `goldInk` yazı | Nadiren (vurgulu çağrı) |
| `.btn.big` | 44 yük. | Form gönder |
| `.btn.act` | 128 gen., 38 yük., 13/600 (telefonda tam genişlik, 44 yük.) | İş kartı ana düğmesi |
| `.btn.act.outline` | 1.5 siyah kenar, beyaz zemin | "Randevu Ver →" |
| `.btn.act.undo` | 1.5 altın kenar, `undoBg` zemin, `midInk` yazı, altta 5 sn'de boşalan 3px altın çubuk | "↶ Geri al · 5" |
| `.mini` | 34 yük., 13 yazı | Tablo satırı işlemleri |
| `.mini.erase` / `.danger` | kırmızı yazı | Sil, Reddet |
| `.more-toggle` | 38×38 (telefonda 44×44) "⋯" | İş kartı menüsü |

Dokunma hedefi en az **44**.

## 4. Rozetler

| Sınıf | Zemin / yazı |
| --- | --- |
| `.pill` | kenarlıklı, `inkSoft` |
| `.pill.ok` | `okBg` / `ok` |
| `.pill.bad`, `.pill.hot` | `badBg` / `bad` |
| `.pill.wait` | `warnBg` / `warn` |
| `.pill.muted` | `chip` / `muted` |
| `.ping` (menü sayacı) | kırmızı daire, beyaz rakam, 18 yük. |
| `.todo` | beyaz yuvarlak çip, solunda 7px nokta: `bad` kırmızı, `warn` altın (+altın kenar ve gölge), `plain` gri |
| `.flag.bad` / `.flag.warn` | iş kartı içi uyarı bandı, 8 köşe; içinde siyah küçük düğme |
| `.loyal.gold` | "★ Sadık müşteri" altın |

## 5. Segment sekmeler (`.seg`)

Çip zeminli kapsayıcı (4 iç boşluk, 11 köşe); her sekme 8 köşe; **seçili** sekme siyah zemin + beyaz yazı, sayacı (`b`) **altın** zemin. Seçili olmayanın sayacı beyaz zemin + ince kenar. Yatay kaydırılabilir. Flutter: `SingleChildScrollView(scrollDirection: Axis.horizontal)` içinde özel `SegmentedTabs` widget'ı (Material `SegmentedButton` görünümü uymaz).

## 6. Yerleşim ve kırılım noktaları

| Genişlik | Davranış |
| --- | --- |
| > 900 | Solda 240 gen. koyu yan menü (`side`), üstte komut çubuğu (selam, arama, "+ Yeni Fiş Oluştur"), içerik kenar boşluğu 32 |
| ≤ 900 | Yan menü gizli → çekmece (☰). Altta **5'li sekme çubuğu**: İşler · Müşteriler · **[+]** · Yorumlar · Menü. Kenar boşluğu 18. Toast altta (sekme çubuğunun üstünde). İçerik alt boşluğu 96 + safe area |
| ≤ 640 | Kenar boşluğu 14; iş satırı karta dönüşür; tablolar kart listesine dönüşür (`cards-on-phone`: her hücre "Etiket: değer" satırı) |
| ≤ 380 | Daha sıkı aralıklar |

Flutter: `LayoutBuilder` ile `width > 900` → `Row(SideNav, Expanded(content))`, değilse `Scaffold(drawer: SideNav, bottomNavigationBar: TabBar5)`. Tablet yatayda masaüstü düzeni kullanılabilir.

**Alt sekme çubuğu** ayrıntısı: 52 yük. öğeler, ikon 21, yazı 11; seçili `ink`/600, diğerleri `muted`. Ortadaki **+** 52×52, 14 köşe, siyah zemin, **altın** "+" (26), gölge `0 6 16 -6 rgba(9,9,11,.5)`. Yorumlar sekmesinde bekleyen şikâyet sayısı `ping` rozeti; Menü düğmesinde şikâyet varsa küçük kırmızı nokta.

## 7. İkonlar

`components/Icon.jsx` çizgi ikon seti (24×24 viewBox, `stroke=currentColor`, `stroke-width≈1.8`, yuvarlak uç). SVG path'leri dosyada; Flutter'a **`flutter_svg`** ile aynen taşıyın (her ikonu `assets/icons/<ad>.svg` yapın) ya da en yakın `lucide_icons` karşılığını kullanın.

| Ad | Kullanım | Lucide karşılığı |
| --- | --- | --- |
| `mark` | Logo (kemer + su dalgası) | özel SVG şart |
| `desk` | İşler | `clipboard-list` |
| `archive` | Arşiv | `archive` |
| `user` | Müşteriler | `user` |
| `star` | Yorumlar, yıldız | `star` |
| `truck` | Servis listesi | `truck` |
| `till` | Kasa | `wallet` / `banknote` |
| `chart` | Analiz | `bar-chart-3` |
| `gear` | Ayarlar | `settings` |
| `building` | İşletme | `building-2` |
| `carpet` `sofa` `quilt` `curtain` | Hizmet ikonları | özel SVG önerilir (`sofa` lucide'da var) |
| `search` `menu` `plus` `check` `arrow` `pin` `call` `chat` `card` `print` `note` `pencil` `trash` `mute` `clock` `flag` `box` `drops` `phone` `sync` `shield` | genel | aynı adlı lucide ikonları |

**Hizmet karosu** (`.svc-tile`): 40×40 (telefonda 36), 10 köşe, `sunk` zemin, `line` kenar, ikon 20.

**Monogram**: Adın ilk iki kelimesinin baş harfleri (`tr-TR` büyük harf, "i"→"İ"), yuvarlak; `large` müşteri kartında.

## 8. Giriş ekranı (gate.css)

İki sütun: solda koyu "hikâye" paneli (marka, ürün önizleme taklidi, "Halı yıkama işinizi tek ekrandan yönetin.", 3 madde ✓), sağda beyaz form paneli. **≤ 900'de yalnız form** görünür. Ayrıntı: [04-kabuk-ve-auth.md](04-kabuk-ve-auth.md).

## 9. Puan sayfası (rating.css)

Ortada tek kart (18 köşe); üst "mast" koyu (`side`) zeminde, ortada 46×46 altın daire içinde işletme adının baş harfi, işletme adı beyaz, "Sayın X" `sideInk`, "Fiş HK1001" altın. Yıldızlar büyük; çipler 44 yük., seçili çip siyah kenar.

## 10. Hareket

- Toast giriş/çıkış ~280 ms.
- "Geri al" alt çubuğu 5 sn'de soldan sağa boşalır (`undo-drain`).
- Stepper çubuğu genişliği 0.3 sn ease.
- `prefers-reduced-motion` → Flutter'da `MediaQuery.disableAnimations` true ise animasyonları kapatın.

## 11. Yazdırma

Web `@media print` ile yalnız fişi/raporu basar. Flutter'da:
- **Fiş** (`PrintSlip`): `pdf` ile 58/80 mm rulo ya da A4 sayfa, `printing.layoutPdf`. İçerik: [09-ortak-bilesenler.md › PrintSlip](09-ortak-bilesenler.md#printslip).
- **Kasa / Servis listesi**: aynı verilerden PDF rapor + paylaş/yazdır.
