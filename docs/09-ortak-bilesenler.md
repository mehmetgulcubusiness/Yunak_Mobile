# 09 — Ortak bileşenler

Her bileşen için: ne yapar, React kaynağı, Flutter karşılığı.

## Field (`components/fields.jsx › Field`)

Etiket + input + **alanın altında** hata/ipucu/not.

```dart
class AppField extends StatelessWidget {
  final String label;
  final String? error;   // varsa kırmızı kenar + altta kırmızı metin (12.5)
  final String? hint;    // gri ipucu (12.5); hata ile birlikte de gösterilir
  final Widget? note;    // altta ek widget (ör. "HK1043 numarasını kullan" düğmesi)
  final Widget? after;   // input'un hemen altında (ör. şifre gücü)
  final Widget child;    // TextField / Dropdown
}
```

- Etiket input'un **üstünde** (Material floating label değil), 13/500 `inkSoft`. Zorunlu alanlar `required` ama yıldız gösterilmez.
- Hata metni erişilebilirlik için `Semantics(liveRegion)`.
- Kullanıcı yazınca o alanın hatası silinir (`clear(key)`).

## PhoneField

- `TextInputType.phone`, placeholder **"05xx xxx xx xx"**, `maxLength 14` (sayaç gizli), `autofillHints: [AutofillHints.telephoneNumber]`.
- Her değişiklikte `maskPhone(value)` → "0532 111 00 31". Flutter'da `TextInputFormatter` olarak yazın (imleç sonda kalsın).
- Sunucuya `parsePhone` ile E.164 gider (`checkPhone(...).value`).

## PasswordField

- Gizli metin + sağda **"Göster" / "Gizle"** metin düğmesi.
- Caps Lock açıksa ipucu **"Caps Lock açık."** (fiziksel klavyede `HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock)`; dokunmatikte gerekmez).
- `strength: true` → altta güç çubuğu + "Şifre gücü: `Çok zayıf|Zayıf|Orta|İyi|Güçlü`" (`passwordStrength`, 0–4 seviye; renk s0–s1 kırmızı, s2 sarı, s3–s4 yeşil).
- `maxLength 72` (asıl sınır 72 UTF-8 bayt, `checkPassword` denetler).

## AmountField

- `TextInputType.numberWithOptions(decimal: true)`, yalnız rakam `.` `,` (`filterAmount`, ≤16).
- Odaktan çıkınca geçerliyse `formatAmount` ile "1.250,00" biçimine geçer; geçersizse `onBlur(outcome)` hatayı alana yazar.
- `preview: true` (varsayılan) ve hata yoksa altta ipucu: **"Bu tutar ₺1.250,00 olarak kaydedilecek."** (IntakeForm'da `preview: false`).
- `Focus(onFocusChange: …)` ile blur yakalayın.

## NewAccountFields

Kayıt ve platform formu ortak 5 alan: İşletme / Marka Adı · Yetkili Adı Soyadı · Cep Telefonu · Şifre (güç + ipucu) · Şifre (tekrar). `checkNewAccount(form)` (bkz. 04 §4).

## ConfirmDialog / `useConfirm` (`components/ConfirmDialog.jsx`)

`window.confirm` yerine. Promise döner: iptal → `null`, onay → `{ note }`.

```dart
Future<ConfirmResult?> confirm(BuildContext context, {
  required String title,
  String? body,
  List<String>? items,          // madde listesi (silinecekler, olacaklar)
  String confirmLabel = 'Onayla',
  String cancelLabel = 'Vazgeç',
  bool danger = false,          // onay düğmesi kırmızı
  String? typeToConfirm,        // ör. müşteri adı ya da "SİL": yazılmadan onay pasif
  NoteSpec? note,               // { label, max, initial } → çok satırlı not alanı, sayaç "n/max"
});
```

- `typeToConfirm` karşılaştırması: iki taraf da `trim()`, **tr-TR büyük harf**, çoklu boşluk tek boşluk. Etiket: "Onaylamak için **`X`** yazın".
- Odak: not/yazma alanı varsa ona, yoksa **Vazgeç**'e (yanlışlıkla onayı önler).
- Yeni bir soru gelirse önceki cevapsız soru "vazgeç" sayılır.
- Flutter: `showDialog` + `AlertDialog` benzeri özel panel; `barrierDismissible: true` (dışına dokununca iptal).

## Sheet (`components/Sheet.jsx`)

Sağdan açılan panel (telefonda tam ekran), başlık + ×. **Kapalıyken de bağlı kalır** → içindeki form verisi kaybolmaz. Flutter: masaüstünde `Stack` + `AnimatedSlide` ile her zaman ağaçta duran panel, telefonda tam ekran route; form state'i provider'da.

## CustomerDrawer

Bkz. [06 §2](06-musteriler-yorumlar.md#2-müşteri-kartı--customerdrawer-componentscustomerdrawerjsx).

## MoreMenu (`components/MoreMenu.jsx`)

"⋯" düğmesi; aynı anda tek menü açık; ekran altına yakınsa yukarı açılır; dışarı dokununca / kaydırınca / Esc ile kapanır; bir öğeye basınca kapanır. `disabled` iken açılmaz. Flutter: `MenuAnchor` (masaüstü) / `showModalBottomSheet` (telefon). Tehlikeli öğeler kırmızı (`bad`).

## Stepper (`components/Stepper.jsx`) — iş aşaması

Üstte rozet "● `Etiket` `adım`/3", altında ince (4px) ilerleme çubuğu (140 gen.; telefonda rozetin yanında tam genişlik).

| status | adım | Halı/Yorgan/Perde etiketi | Koltuk etiketi | ton | çubuk % |
| --- | --- | --- | --- | --- | --- |
| `draft` | 0 | Randevu bekliyor | Randevu bekliyor | wait (beyaz, kenarlı, içi boş nokta; "x/3" yazmaz) | 10 |
| `received`, `scheduled` | 1 | Teslim alındı | Randevulu | start (chip zemin, siyah çubuk) | 40 |
| `washing`, `in_progress` | 2 | Yıkamada | İşlemde | mid (`midBg`/`midInk`, çubuk `midBar` yeşil) | 75 |
| `delivered`, `completed` | 3 | Teslim edildi | Bitti | done (`okBg`/`ok`) | 100 |

Koltuk = `serviceType == 'sofa_wash'`. Erişilebilirlik: "İşin durumu: `Etiket`, `adım`/3".

## DayGroups (`components/DayGroups.jsx`)

Teslim edilmiş işleri **teslim gününe** göre bantlara böler (liste sunucudan yeniden eskiye sıralı gelir):

```dart
key = istanbulDayKey(item.deliveredAt ?? item.createdAt)   // "2026-11-27"
// ardışık aynı key'ler bir grupta
```

Bant başlığı: solda `dayHeading(key)` ("Bugün", "Dün", "2 Kasım Pazartesi", başka yılsa "2 Kasım 2025 Pazar"), sağda "`count` teslim" + (`totalTry` sayıysa) " · `money(totalTry)`". `count`/`totalTry` sunucunun `days` dizisinden gelir (sayfa bölünse de günün tamamı); yoksa gruptaki adet. Flutter: `SliverList` + yapışkan başlık (`SliverPersistentHeader` veya `sticky_headers`).

## Pager (`components/Pager.jsx`)

- Sayfa boyu **50**. `pages = max(1, ceil(total/50))`.
- Tek sayfa: "Toplam `total` `kayıt` gösteriliyor".
- Çok sayfa: "Toplam `total` `kayıttan` `from`–`to` arası gösteriliyor" + **[← Önceki]** "Sayfa `p` / `pages`" **[Sonraki →]**; sayfa değişince başa kaydır.
- İsimler: varsayılan `kayıt`/`kayıttan`; müşteri `müşteri`/`müşteriden`; puan `puan`/`puandan`.
- `readPage`: URL'deki `page` sayı değilse ya da <1 ise 1, değilse `floor`.

> Flutter'da isterseniz sonsuz kaydırma kullanın; ama sayaç metni ve `page` düzeltme mantığı korunmalı.

## ListState (`components/States.jsx`)

Listenin üstündeki durum satırı:

| Koşul | Görünüm |
| --- | --- |
| `error && data == null` | Kırmızı kutu: hata mesajı (yoksa "Liste yüklenemedi.") + **[Yeniden dene]** |
| `stale` (sessiz yenileme başarısız, eski veri var) | Sarı kutu: "Liste güncellenemedi. Gösterilen bilgiler eski olabilir." + **[Yenile]** |
| `!loading && data != null && count == 0` | Boş kutu: arama varsa `searchEmpty` (yoksa "Aramayla eşleşen kayıt yok.") + "Farklı bir ad, telefon veya fiş numarası deneyin.", değilse `empty` |

İskeletler: `CardSkeleton(count: 3)` (3 gri çizgili kart), `TableSkeleton(columns, rows: 4)`. Flutter: `shimmer` paketi ya da düz gri kutular (hareket azaltma açıksa animasyonsuz).

## Monogram

Adın ilk iki kelimesinin baş harfi, `toUpperCase` **tr-TR** ("ismail" → "İ"). Dart'ta `String.toUpperCase()` Türkçe değildir: `i → İ`, `ı → I` dönüşümünü elle yapın (bkz. 10 › `trUpper`).

## Toast

Bkz. [01 §6](01-mimari.md#6-global-ui-parçaları). Ton `good` (koyu zemin/yeşil vurgu) veya `bad` (kırmızı), 3,8 / 6 sn, ×.

## Banners

`NetworkBanner`, `VersionNotice` — bkz. 01 §6.

## PrintSlip

Yazdırılan müşteri fişi (ekranda görünmez):

```text
<İŞLETME ADI>            (h1)
<işletme telefonu>       (varsa)
────────────
Fiş No: HK1001
27.11.2026 14:05         (formatStamp(createdAt))
────────────
**Ayşe Yılmaz**
0532 111 00 31
<adres>                  (varsa)
────────────
Halı Yıkama
<masa notu>              (varsa)
Tutar: 1.250,50 ₺        (tutar varsa)
────────────
Bizi tercih ettiğiniz için teşekkür ederiz.
```

Flutter: `pdf` paketiyle `PdfPageFormat.roll80` (80 mm) varsayılan, A4 seçeneği; `Printing.layoutPdf`. Fontu Inter TTF olarak gömün (Türkçe karakterler).

## Charts (`components/charts.jsx`)

| React | Flutter |
| --- | --- |
| `ChartFrame` (başlık, ipucu, Tablo/Grafik geçişi) | `ChartPanel` widget'ı |
| `ColumnChart` (sütun, son sütun vurgulu, `niceMax` eksen) | `fl_chart` `BarChart` |
| `LineChart` (boşluklu çizgi, min/max/ticks) | `fl_chart` `LineChart` (null nokta → `FlSpot.nullSpot`) |
| `BarList` (yatay çubuk listesi; değer >0 ise en az %1.5) | `Row(label, Expanded(LinearProgressIndicator), value)` |
| `Heatmap` (gün × saat) | `Table` + renk seviyesi |
| `Meter` (0–100) | `LinearProgressIndicator` + "%x" |
| `StatTile` (KPI + delta ▲▼■) | `KpiCard` (DayLine ile aynı stil) |

## Icon

Bkz. [03 §7](03-tasarim.md#7-ikonlar).
