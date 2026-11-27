// Form kuralları. Kaynak sunucudur: ccs_server/src/models/validation.ts, domain/phone.ts,
// domain/text.ts. Web karşılığı ccs_client/src/utils/validate.js. Ortak vakalar
// test/contract_cases.json. Bir kural değişirse üç yerde birlikte değişmeli.

import 'dart:convert';

import 'package:intl/intl.dart';

import '../api/api_error.dart';

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
const phoneMaskLength = 14;

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
  String cut(int from, int to) => d.length <= from ? '' : d.substring(from, d.length < to ? d.length : to);
  return [cut(0, 4), cut(4, 7), cut(7, 9), cut(9, 11)].where((p) => p.isNotEmpty).join(' ');
}

/// İşletmenin gösterim numarası. Boş olabilir.
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

/// Türkçe harf → ASCII, BÜYÜK harf (en-US: "i" → "I", asla "İ"), yalnız A-Z 0-9 -.
String filterReference(String? input) {
  final mapped = (input ?? '').split('').map((c) => _trAscii[c] ?? c).join();
  final s = mapped.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
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

/// Virgül ondalık, nokta yalnız binlik. Boş → (null, null).
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

String _group4(String s) => s.replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]} ');

/// "TR330006100519786457841326" → "TR33 0006 1005 1978 6457 8413 26"
String maskIban(String? input) => _group4(compactIban(input));

bool ibanChecksumOk(String compact) {
  if (compact.length < 5) return false;
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
  return _ok(_group4(c));
}

// ------------------------------------------------------------------ Şifre
const passwordMinBytes = 8;
const passwordMaxBytes = 72;
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
      (RegExp(r'\p{Lu}', unicode: true).hasMatch(raw) && RegExp(r'\p{Ll}', unicode: true).hasMatch(raw))) {
    s++;
  }
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
const addressMax = 240;
const deskNoteMax = 160;
const platformNoteMax = 300;
const ratingNoteMax = 1000;
const wapioMax = 128;
const customerNoteMax = 500;

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
  'invalid_phone': 'phone',
  'phone_taken': 'phone',
  'invalid_name': 'name',
  'invalid_reference': 'reference',
  'reference_taken': 'reference',
  'invalid_amount': 'amount',
  'invalid_password': 'password',
  'weak_password': 'password',
  'password_is_phone': 'password',
  'invalid_credentials': 'password',
  'invalid_business_name': 'business',
  'address_too_long': 'address',
  'note_too_long': 'note',
  'settings_iban': 'ibanNumber',
  'settings_public': 'publicPhone',
  'settings_url': 'googleReviewUrl',
  'settings_session': 'wapioSessionId',
  'settings_alert': 'alertPhone',
};

String? fieldOfError(Object? error, [Map<String, String> overrides = const {}]) {
  if (error is! ApiError) return null;
  if (overrides.containsKey(error.code)) return overrides[error.code];
  final f = error.field;
  if (f != null) return overrides[f] ?? f;
  return fieldByCode[error.code];
}

typedef CheckResult = ({Map<String, String> errors, Map<String, Object?> values, bool valid});

/// { 'name': () => checkPersonName(x), ... } → hatalar ve değerler.
CheckResult runChecks(Map<String, Check<Object> Function()> rules) {
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
