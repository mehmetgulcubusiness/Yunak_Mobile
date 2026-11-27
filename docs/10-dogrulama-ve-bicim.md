# 10 — Doğrulama, biçimlendirme ve sabit metinler

Kurallar **sunucuyla birebir aynı** olmalıdır (kaynak: `ccs_server/src/models/validation.ts`, `domain/phone.ts`, `domain/text.ts`). Web'deki karşılıkları `src/utils/validate.js` ve `src/utils/format.js`. Ortak test vakaları `src/utils/contract-cases.json` → Flutter projesine kopyalayıp Dart testinde okuyun; bir kural değişirse üç yerde (sunucu, web, Flutter) birlikte değişir.

Her `check*` fonksiyonu `Check(value, error)` döner: `error` Türkçe mesaj ya da `null`; `value` sunucuya gidecek normalleşmiş değer.

## 1. Dart: doğrulama (`lib/core/validation/validate.dart`)

```dart
import 'dart:convert';
import 'package:intl/intl.dart';

class Check<T> {
  const Check(this.value, this.error);
  final T? value;
  final String? error;
  bool get ok => error == null;
}
Check<T> _ok<T>(T? v) => Check<T>(v, null);
Check<T> _fail<T>(String e) => Check<T>(null, e);

// ---------------------------------------------------------------- Telefon
const phoneInputMax = 32;
const phoneMaskLength = 14; // "0532 111 00 31"

/// Türk cep telefonu → "+905xxxxxxxxx" ya da null.
String? parsePhone(String? input) {
  final raw = input ?? '';
  if (raw.length > phoneInputMax) return null;
  final compact = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (compact.isEmpty) return null;
  var d = compact;
  if (d.startsWith('+')) {
    d = d.substring(1);
  } else if (d.startsWith('00')) {
    d = d.substring(2);
  }
  if (!RegExp(r'^\d+$').hasMatch(d)) return null;
  if (d.startsWith('90') && d.length == 12) {
    d = d.substring(2);
  } else if (d.startsWith('0') && d.length == 11) {
    d = d.substring(1);
  }
  if (!RegExp(r'^5\d{9}$').hasMatch(d)) return null;
  return '+90$d';
}

Check<String> checkPhone(String? input, {bool required = true}) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return required ? _fail('Cep telefonu girin.') : _ok(null);
  final p = parsePhone(raw);
  return p != null ? _ok(p) : _fail('Geçerli bir cep telefonu girin (05xx xxx xx xx).');
}

/// Yazarken maske: "05321110031" → "0532 111 00 31".
String maskPhone(String? input) {
  var d = (input ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('90') && d.length >= 3) {
    d = '0${d.substring(2)}';
  } else if (d.startsWith('5')) {
    d = '0$d';
  }
  if (d.length > 11) d = d.substring(0, 11);
  final parts = <String>[
    if (d.isNotEmpty) d.substring(0, d.length.clamp(0, 4)),
    if (d.length > 4) d.substring(4, d.length.clamp(4, 7)),
    if (d.length > 7) d.substring(7, d.length.clamp(7, 9)),
    if (d.length > 9) d.substring(9, d.length.clamp(9, 11)),
  ];
  return parts.join(' ');
}

/// İşletmenin gösterim numarası (sabit hat / cep / 0850 / 444 xx xx). Boş olabilir.
Check<String> checkPublicPhone(String? input) {
  final value = (input ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return _ok(null);
  final bad = _fail<String>('Gösterim numarası geçersiz. Ör: 0216 123 45 67');
  if (value.length > phoneInputMax || !RegExp(r'^[0-9 +()-]+$').hasMatch(value)) return bad;
  var d = value.replaceAll(RegExp(r'\D'), '');
  if (value.startsWith('+')) {
    if (!d.startsWith('90')) return bad;
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = d.substring(1);
  }
  if (!RegExp(r'^[2-58]\d{9}$').hasMatch(d) && !RegExp(r'^444\d{4}$').hasMatch(d)) return bad;
  return _ok(value);
}

String filterPublicPhone(String? input) {
  final s = (input ?? '').replaceAll(RegExp(r'[^0-9 +()-]'), '');
  return s.length > phoneInputMax ? s.substring(0, phoneInputMax) : s;
}

// --------------------------------------------------------------------- Ad
const nameMax = 120;

String? normalizePersonName(String? input) {
  final collapsed = (input ?? '').replaceAll(RegExp(r'[\s\u0000-\u001F]+', unicode: true), ' ').trim();
  return RegExp(r"^\p{L}[\p{L}\s'.-]{0,119}$", unicode: true).hasMatch(collapsed) ? collapsed : null;
}

Check<String> checkPersonName(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return _fail('Ad soyad girin.');
  if (raw.length > nameMax) return _fail('Ad en fazla $nameMax karakter olabilir.');
  if (!RegExp(r'^\p{L}', unicode: true).hasMatch(raw)) return _fail('Ad bir harfle başlamalı.');
  final v = normalizePersonName(raw);
  return v != null ? _ok(v) : _fail("Ad yalnız harf, boşluk ve ' . - içerebilir.");
}

Check<String> checkBrandName(String? input) {
  final v = (input ?? '')
      .replaceAll(RegExp(r'[\u0000-\u001F]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+', unicode: true), ' ')
      .trim();
  if (v.isEmpty) return _fail('İşletme adı girin.');
  if (v.length > nameMax) return _fail('İşletme adı en fazla $nameMax karakter olabilir.');
  return _ok(v);
}

// ----------------------------------------------------------------- Fiş no
const referenceMax = 32;
final _referenceShape = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,31}$');
const _trAscii = {'ç': 'C', 'Ç': 'C', 'ğ': 'G', 'Ğ': 'G', 'ı': 'I', 'İ': 'I', 'ö': 'O', 'Ö': 'O', 'ş': 'S', 'Ş': 'S', 'ü': 'U', 'Ü': 'U'};

/// Türkçe harf → ASCII, BÜYÜK harf (en-US; "i" → "I", asla "İ"), yalnız A-Z 0-9 -.
String filterReference(String? input) {
  final mapped = (input ?? '').split('').map((c) => _trAscii[c] ?? c).join();
  final upper = mapped.toUpperCase(); // Dart toUpperCase dilden bağımsız = en-US davranışı
  final s = upper.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  return s.length > referenceMax ? s.substring(0, referenceMax) : s;
}

Check<String> checkReference(String? input) {
  final v = (input ?? '').trim().toUpperCase();
  if (v.isEmpty) return _fail('Fiş numarası girin.');
  return _referenceShape.hasMatch(v) ? _ok(v) : _fail('Fiş numarası 2–32 harf, rakam veya tire olmalı (Türkçe harf olmaz).');
}

// ------------------------------------------------------------------ Tutar
const amountMax = 1000000;
final _amountShape = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?$');

/// Virgül ondalık, nokta yalnız binlik. "1.250" → 1250, "1,25" → 1.25, "1.25" → hata. Boş → (null, null).
Check<double> parseAmount(String? input) {
  final text = (input ?? '').trim().replaceAll('₺', '').replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return _ok(null);
  final m = _amountShape.firstMatch(text);
  if (m == null) {
    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(text)) return _fail('Kuruş için virgül kullanın: ${text.replaceFirst('.', ',')}');
    if (text.startsWith('-')) return _fail('Tutar eksi olamaz.');
    return _fail('Tutar geçersiz. Ör: 1.250,50');
  }
  final whole = m.group(1)!.replaceAll('.', '');
  if (whole.length > 7) return _fail('Tutar en fazla 1.000.000 ₺ olabilir.');
  final frac = m.group(2);
  final value = double.parse(frac == null ? whole : '$whole.$frac');
  if (!value.isFinite || value < 0) return _fail('Tutar geçersiz. Ör: 1.250,50');
  if (value > amountMax) return _fail('Tutar en fazla 1.000.000 ₺ olabilir.');
  return _ok((value * 100).round() / 100);
}

/// Tutar/miktar kutusuna yalnız rakam, nokta, virgül (en fazla 16).
String filterAmount(String? input) {
  final s = (input ?? '').replaceAll(RegExp(r'[^\d.,]'), '');
  return s.length > 16 ? s.substring(0, 16) : s;
}

final _groupedTr = NumberFormat('#,##0.00', 'tr_TR');
/// 1250.5 → "1.250,50"
String formatAmount(double? v) => v == null ? '' : _groupedTr.format(v);

/// Sunucuya giden biçim: 1250.5 → "1250,5", 1250 → "1250", null → "".
String amountWire(double? v) {
  if (v == null) return '';
  final cents = (v * 100).round();
  final whole = cents ~/ 100;
  final frac = cents % 100;
  if (frac == 0) return '$whole';
  return '$whole,${frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
}

// ------------------------------------------------------------------- IBAN
String compactIban(String? input) {
  var c = (input ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (RegExp(r'^\d').hasMatch(c)) c = 'TR$c';
  return c.length > 26 ? c.substring(0, 26) : c;
}

/// "TR330006100519786457841326" → "TR33 0006 1005 1978 6457 8413 26"
String maskIban(String? input) => compactIban(input).replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]} ');

bool ibanChecksumOk(String compact) {
  final moved = compact.substring(4) + compact.substring(0, 4);
  var r = 0;
  for (final ch in moved.split('')) {
    final code = RegExp(r'[A-Z]').hasMatch(ch) ? '${ch.codeUnitAt(0) - 55}' : ch;
    for (final d in code.split('')) {
      r = (r * 10 + int.parse(d)) % 97;
    }
  }
  return r == 1;
}

Check<String> checkIban(String? input) {
  final c = (input ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (c.isEmpty) return _ok(null);
  if (!RegExp(r'^TR\d{24}$').hasMatch(c)) return _fail('IBAN TR ile başlamalı ve 26 karakter olmalıdır.');
  if (!ibanChecksumOk(c)) return _fail('IBAN hatalı görünüyor; rakamları kontrol edin.');
  return _ok(c.replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]} '));
}

// ------------------------------------------------------------------ Şifre
const passwordMinBytes = 8, passwordMaxBytes = 72;
int utf8Length(String s) => utf8.encode(s).length;

Check<String> checkPassword(String? input) {
  final raw = input ?? '';
  if (raw.isEmpty) return _fail('Şifre girin.');
  final b = utf8Length(raw);
  if (b < passwordMinBytes || b > passwordMaxBytes) return _fail('Şifre 8–72 karakter olmalı.');
  return _ok(raw);
}

Check<String> checkNewPassword(String? input, [String? phone]) {
  final base = checkPassword(input);
  if (!base.ok) return base;
  final raw = base.value!;
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(raw) || !RegExp(r'\p{Nd}', unicode: true).hasMatch(raw)) {
    return _fail('Şifre en az bir harf ve bir rakam içermeli.');
  }
  final e164 = parsePhone(phone);
  if (e164 != null) {
    final national = e164.substring(3);
    final compact = raw.replaceAll(RegExp(r'[\s().-]+', unicode: true), '');
    if ([e164, e164.substring(1), national, '0$national'].contains(compact)) return _fail('Şifre telefon numarasıyla aynı olamaz.');
  }
  return _ok(raw);
}

Check<String> checkPasswordRepeat(String password, String? repeat) {
  if (repeat == null || repeat.isEmpty) return _fail('Şifreyi tekrar girin.');
  return password == repeat ? _ok(repeat) : _fail('Şifreler aynı değil.');
}

/// Güç göstergesi (kural değil): 0–4.
({int score, String label}) passwordStrength(String? input) {
  final raw = input ?? '';
  if (raw.isEmpty) return (score: 0, label: '');
  var s = 0;
  if (raw.length >= 8) s++;
  if (raw.length >= 12) s++;
  if (RegExp(r'\p{L}', unicode: true).hasMatch(raw) && RegExp(r'\p{Nd}', unicode: true).hasMatch(raw)) s++;
  if (RegExp(r'[^\p{L}\p{Nd}]', unicode: true).hasMatch(raw) ||
      (RegExp(r'\p{Lu}', unicode: true).hasMatch(raw) && RegExp(r'\p{Ll}', unicode: true).hasMatch(raw))) s++;
  const labels = ['Çok zayıf', 'Zayıf', 'Orta', 'İyi', 'Güçlü'];
  return (score: s, label: labels[s]);
}

// ----------------------------------------------------------- Google linki
const googleUrlMax = 500;
final _googleHost = RegExp(r'(^|\.)(google\.[a-z]{2,3}(\.[a-z]{2})?|g\.page|g\.co|goo\.gl)$', caseSensitive: false);

Check<String> checkGoogleUrl(String? input) {
  final v = (input ?? '').trim();
  if (v.isEmpty) return _ok(null);
  if (v.length > googleUrlMax) return _fail('Google linki çok uzun.');
  final u = Uri.tryParse(v);
  if (u == null || u.scheme != 'https' || u.host.isEmpty || u.userInfo.isNotEmpty) {
    return _fail('Google yorum linki https:// ile başlayan bir adres olmalı.');
  }
  if (!_googleHost.hasMatch(u.host)) return _fail('Bu bir Google adresi değil (google.com, g.page, g.co veya goo.gl olmalı).');
  return _ok(v);
}

// --------------------------------------------------------- Diğer alanlar
const addressMax = 240, deskNoteMax = 160, platformNoteMax = 300, ratingNoteMax = 1000, wapioMax = 128, customerNoteMax = 500;

Check<String> checkLine(String? input, int max, String label) {
  final v = (input ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (v.length > max) return _fail('$label en fazla $max karakter olabilir.');
  return _ok(v.isEmpty ? null : v);
}

Check<String> checkWapio(String? input) {
  final v = (input ?? '').trim();
  if (v.length > wapioMax || RegExp(r'[\u0000-\u001f\u007f]').hasMatch(v)) return _fail('Wapio oturum anahtarı geçersiz.');
  return _ok(v.isEmpty ? null : v);
}

// ------------------------------------------------- Sunucu hatası → alan
const fieldByCode = {
  'invalid_phone': 'phone', 'phone_taken': 'phone', 'invalid_name': 'name',
  'invalid_reference': 'reference', 'reference_taken': 'reference', 'invalid_amount': 'amount',
  'invalid_password': 'password', 'weak_password': 'password', 'password_is_phone': 'password',
  'invalid_credentials': 'password', 'invalid_business_name': 'business',
  'address_too_long': 'address', 'note_too_long': 'note',
  'settings_iban': 'ibanNumber', 'settings_public': 'publicPhone', 'settings_url': 'googleReviewUrl',
  'settings_session': 'wapioSessionId', 'settings_alert': 'alertPhone',
};

String? fieldOfError(ApiError? e, [Map<String, String> overrides = const {}]) {
  if (e == null) return null;
  if (overrides.containsKey(e.code)) return overrides[e.code];
  final f = e.field;
  if (f != null) return overrides[f] ?? f;
  return fieldByCode[e.code];
}

/// { 'name': () => checkPersonName(x), ... } → hatalar ve değerler.
({Map<String, String> errors, Map<String, Object?> values, bool valid}) runChecks(Map<String, Check Function()> rules) {
  final errors = <String, String>{};
  final values = <String, Object?>{};
  rules.forEach((k, rule) {
    final o = rule();
    if (o.error != null) {
      errors[k] = o.error!;
    } else {
      values[k] = o.value;
    }
  });
  return (errors: errors, values: values, valid: errors.isEmpty);
}
```

### Dikkat edilecek Dart farkları

- **Unicode regex:** `\p{L}` için `RegExp(..., unicode: true)` şart.
- **Büyük harf:** Dart `toUpperCase()` dilden bağımsızdır (en-US gibi; "i" → "I"). Fiş no için doğru olan budur. Ama **Monogram, onay metni karşılaştırma (`typeToConfirm`), önizleme balonundaki işletme adı** tr-TR büyük harf ister:
  ```dart
  String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  ```
- **JS `String.length` UTF-16 birimi sayar**, Dart `String.length` de UTF-16 → sınırlar aynı davranır. Şifre ise **UTF-8 bayt** ile ölçülür.
- **`maxLength`**: `TextField(maxLength: n, buildCounter: (…) => null)` ya da `LengthLimitingTextInputFormatter(n)`.

## 2. Dart: biçimlendirme (`lib/core/format/format.dart`)

Türkiye 2016'dan beri yaz saati uygulamaz, sabit **UTC+3**. Web de gün anahtarlarında `T12:00:00+03:00` kullanır. En basit ve doğru yol:

```dart
DateTime toIstanbul(DateTime d) => d.toUtc().add(const Duration(hours: 3)); // "duvar saati" olarak kullanın, isUtc=true kalır
DateTime? parseTime(Object? v) {
  if (v == null || v == '') return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v');
}
String _fmt(DateFormat f, Object? v) { final d = parseTime(v); return d == null ? '' : f.format(toIstanbul(d)); }
```

(İleride kural değişirse `timezone` paketiyle `tz.getLocation('Europe/Istanbul')`'a geçilir.)

`main()` içinde: `await initializeDateFormatting('tr_TR'); Intl.defaultLocale = 'tr_TR';`

| Fonksiyon | Web | Dart | Örnek |
| --- | --- | --- | --- |
| `formatClock` | `hour:2-digit, minute:2-digit` | `DateFormat('HH:mm','tr')` | 14:05 |
| `formatDay` | `day numeric, month short, year` | `DateFormat('d MMM y','tr')` | 27 Kas 2026 |
| `formatStamp` | `dd.MM.yyyy HH:mm` | `DateFormat('dd.MM.y HH:mm','tr')` | 27.11.2026 14:05 |
| `formatMonth` / `monthLabel("2026-11")` | `month long, year` | `DateFormat('MMMM y','tr')` | Kasım 2026 |
| `formatToday` | `weekday long, day, month long` | `DateFormat('d MMMM EEEE','tr')` | 27 Kasım Cuma |
| `formatWeekday(key)` | `weekday short` | `DateFormat('EEE','tr')` | Cum |
| `istanbulDayKey` | `en-CA` → `YYYY-MM-DD` | `DateFormat('yyyy-MM-dd')` (İstanbul'a çevrilmiş) | 2026-11-27 |
| `dayHeading(key)` | Bugün / Dün / uzun gün (başka yılsa yıl ile) | `d MMMM EEEE` / `d MMMM y EEEE` | 2 Kasım Pazartesi |
| `greeting` | İstanbul saati 5–12 / 12–18 / diğer | | Günaydın / İyi günler / İyi akşamlar |

Geçersiz/boş tarih → **boş string** (ekran çökmez).

```dart
/// 1250.5 → "1.250,50 ₺"; 1250 → "1.250 ₺"; null → null
String? money(num? v) {
  if (v == null || !v.isFinite) return null;
  final isInt = v == v.roundToDouble();
  final f = NumberFormat(isInt ? '#,##0' : '#,##0.00', 'tr_TR');
  return '${f.format(v)} ₺';
}

/// Tutar kutusu için: 1250.5 → "1.250,50", 1250 → "1.250" (web amountField)
String amountField(num? v) {
  if (v == null || !v.isFinite) return '';
  final isInt = v == v.roundToDouble();
  return NumberFormat(isInt ? '#,##0' : '#,##0.00', 'tr_TR').format(v);
}

/// "+905321110031" → "0532 111 00 31"
String displayPhone(String? e164) {
  final d = (e164 ?? '').replaceAll(RegExp(r'\D'), '');
  final local = d.startsWith('90') && d.length == 12 ? '0${d.substring(2)}' : d;
  if (local.length != 11) return e164 ?? '';
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7, 9)} ${local.substring(9)}';
}

String phoneDigits(String? e164) => (e164 ?? '').replaceAll(RegExp(r'\D'), '');

/// m² × birim fiyat → toplam kutusu metni ("1250,5"); 1.000.000'u geçerse null
String? meterTotal(String area, String rate) {
  final l = parseAmount(area).value, r = parseAmount(rate).value;
  if (l == null || r == null) return null;
  final cents = (l * r * 100).round();
  if (cents < 0 || cents > amountMax * 100) return null;
  return amountWire(cents / 100);
}

double? meterProduct(String area, String rate) {
  final l = parseAmount(area).value, r = parseAmount(rate).value;
  if (l == null || r == null) return null;
  return (l * r * 100).round() / 100;
}

String mapsHref(String address) => 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
String telHref(String? e164) => 'tel:+${phoneDigits(e164)}';
String waHref(String? e164, [String? text]) =>
    'https://wa.me/${phoneDigits(e164)}${text == null ? '' : '?text=${Uri.encodeComponent(text)}'}';
```

Grafik yardımcıları (`utils/chart.js`):

```dart
double niceMax(double v) {
  if (!v.isFinite || v <= 0) return 1;
  final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final step = [1, 2, 2.5, 5, 10].firstWhere((c) => c * p >= v, orElse: () => 10);
  return step * p;
}
/// ≥10.000 → kısa ("25 B", "2,5 Mn"), altı → "1.250,5"
String axisNumber(num v) => v.abs() >= 10000
    ? NumberFormat.compact(locale: 'tr_TR').format(v)
    : NumberFormat('#,##0.#', 'tr_TR').format(v);
int? change(num now, num? before) => (before == null || before == 0) ? null : (((now - before) / before) * 100).round();
```

> `NumberFormat.compact('tr_TR')` çıktısını web'le (`25 B`, `2,5 Mn`) bir testle karşılaştırın; farklıysa elle "B"/"Mn" ekleyin.

## 3. Sabit metinler (`constants/labels.js` → `labels.dart`)

```dart
const statusLabels = {
  'draft': 'Yeni', 'received': 'Teslim alındı', 'washing': 'Yıkamada', 'delivered': 'Teslim edildi',
  'cancelled': 'İptal', 'scheduled': 'Randevulu', 'in_progress': 'İşlemde', 'completed': 'Bitti',
};

const moveLabels = {
  'received': 'Teslim alındı', 'washing': 'Yıkamada', 'delivered': 'Teslim edildi',
  'scheduled': 'Randevu Ver', 'in_progress': 'Hemen Başla', 'completed': 'İşi Bitir',
};

class Service {
  const Service(this.value, this.title, this.short, this.icon, this.pick, this.unit);
  final String value, title, short, icon, pick, unit;
}
const services = [
  Service('carpet_wash', 'Halı Yıkama', 'Halı', 'carpet', 'Halı', 'm²'),
  Service('sofa_wash', 'Koltuk Yıkama', 'Koltuk', 'sofa', 'Koltuk', 'Adet'),
  Service('quilt_wash', 'Yorgan / Battaniye', 'Yorgan', 'quilt', 'Yorgan', 'Adet'),
  Service('curtain_wash', 'Perde / Stor', 'Perde', 'curtain', 'Perde', 'm²'),
];
Service serviceOf(String? v) => services.firstWhere((s) => s.value == v, orElse: () => services.first);

const roleLabels = {'super_admin': 'Platform Yöneticisi', 'admin': 'Yönetici', 'staff': 'Personel'};

const businessStatusLabels = {'pending': 'Onay Bekliyor', 'active': 'Aktif', 'suspended': 'Askıda', 'rejected': 'Reddedildi'};

const feedbackReasons = [
  ('stain_remains', 'Leke çıkmadı'), ('odor', 'Koku var'), ('delivery_delay', 'Teslimat gecikti'),
  ('damage', 'Hasar veya deformasyon'), ('staff', 'Personel'),
  ('wetness_or_residue', 'Islaklık veya kalıntı'), ('other', 'Başka bir sorun'),
];

const starCaptions = {1: 'Çok Kötü', 2: 'Kötü', 3: 'Orta', 4: 'İyi', 5: 'Mükemmel'};

/// "★ Yıldız İste" atlandığında gösterilen neden
const skipReasonLabels = {
  'not_success_terminal': 'İş henüz bitmedi.',
  'customer_opted_out': 'Müşteri mesajları kapattı.',
  'already_submitted': 'Müşteri zaten puan verdi.',
  'invitation_closed': 'Bu iş için puan isteği kapandı.',
  'already_opened': 'Müşteri linki açtı. Süresi dolmadan yeniden gönderilmez.',
  'already_sent': 'Puan linki zaten gönderildi.',
  'resend_limit': 'Tek yeniden gönderim hakkı kullanıldı.',
  'expired_needs_manual': 'Linkin süresi doldu.',
  'missing_anchor': 'İşin bitiş zamanı yok.',
  'covered_by_batch': 'Bu müşteriye aynı gün başka bir iş için link gitti.',
  'cooldown': 'Bu müşteriye son 7 günde puan linki gönderildi.',
  'order_voided': 'Teslimat geçersiz sayıldı.',
};

({String label, String tone}) loyaltyOf(int orderCount) {
  if (orderCount >= 5) return (label: '★ Sadık müşteri', tone: 'gold');
  if (orderCount >= 2) return (label: 'Tekrar gelen', tone: 'plain');
  return (label: 'Yeni müşteri', tone: 'plain');
}
```

## 4. Ortak test vakaları

`ccs_client/src/utils/contract-cases.json` dosyasını `test/fixtures/contract_cases.json` olarak kopyalayın ve aynı vakaları Dart'ta çalıştırın (`validate.test.js` ile aynı yapı). Ayrıca `format.test.js` ve `edge-cases.test.jsx` içindeki örnekleri (`displayPhone`, `money`, `dayHeading`, bozuk tarih → boş) Dart testine çevirin.

```dart
void main() {
  final cases = jsonDecode(File('test/fixtures/contract_cases.json').readAsStringSync());
  // her grup için: parsePhone / parseAmount / checkReference / checkIban / checkNewPassword ...
}
```
