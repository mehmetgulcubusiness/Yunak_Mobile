// Biçimlendirme. Web karşılığı ccs_client/src/utils/format.js.
// Bütün gösterimler Europe/Istanbul. Türkiye 2016'dan beri sabit UTC+3'tür.

import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../validation/validate.dart';

const _istanbulOffset = Duration(hours: 3);

/// Anın İstanbul "duvar saati" (isUtc=true kalır; yalnız biçimlendirmek için).
DateTime toIstanbul(DateTime d) => d.toUtc().add(_istanbulOffset);

DateTime? parseTime(Object? v) {
  if (v == null || v == '') return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v');
}

String _fmt(String pattern, Object? v) {
  final d = parseTime(v);
  return d == null ? '' : DateFormat(pattern, 'tr_TR').format(toIstanbul(d));
}

/// 14:05
String formatClock(Object? v) => _fmt('HH:mm', v);

/// 27 Kas 2026
String formatDay(Object? v) => _fmt('d MMM y', v);

/// 27.11.2026 14:05
String formatStamp(Object? v) => _fmt('dd.MM.y HH:mm', v);

/// Kasım 2026
String formatMonth(Object? v) => _fmt('MMMM y', v);

/// 27 Kasım Cuma
String formatToday(Object? v) => _fmt('d MMMM EEEE', v);

/// "2026-11-27" → "Cum"
String formatWeekday(String key) => _fmt('EEE', '${key}T12:00:00+03:00');

/// Anın düştüğü İstanbul takvim günü: "YYYY-MM-DD".
String istanbulDayKey(Object? v) {
  final d = parseTime(v);
  if (d == null) return '';
  final t = toIstanbul(d);
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// İstanbul saatine göre selam.
String greeting(DateTime now) {
  final hour = toIstanbul(now).hour;
  if (hour >= 5 && hour < 12) return 'Günaydın';
  if (hour >= 12 && hour < 18) return 'İyi günler';
  return 'İyi akşamlar';
}

/// Liste gün başlığı: "Bugün", "Dün", "2 Kasım Pazartesi"; başka yıl ise yıl da yazılır.
String dayHeading(String? key, [DateTime? now]) {
  final today = now ?? DateTime.now();
  if (key == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return 'Tarihsiz';
  if (key == istanbulDayKey(today)) return 'Bugün';
  if (key == istanbulDayKey(today.subtract(const Duration(days: 1)))) return 'Dün';
  final noon = '${key}T12:00:00+03:00';
  return key.substring(0, 4) == istanbulDayKey(today).substring(0, 4) ? _fmt('d MMMM EEEE', noon) : _fmt('d MMMM y EEEE', noon);
}

/// "2026-11" → "Kasım 2026".
String monthLabel(String? key) {
  if (key == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(key)) return key ?? '';
  final shown = _fmt('MMMM y', '$key-15T12:00:00+03:00');
  return shown.isEmpty ? key : shown;
}

bool _isInt(num v) => v == v.roundToDouble();

/// 1250.5 → "1.250,50 ₺"; 1250 → "1.250 ₺"; null → null
String? money(num? v) {
  if (v == null || !v.isFinite) return null;
  return '${NumberFormat(_isInt(v) ? '#,##0' : '#,##0.00', 'tr_TR').format(v)} ₺';
}

/// Tutar kutusu için: 1250.5 → "1.250,50", 1250 → "1.250".
String amountField(num? v) {
  if (v == null || !v.isFinite) return '';
  return NumberFormat(_isInt(v) ? '#,##0' : '#,##0.00', 'tr_TR').format(v);
}

/// "+905321110031" → "0532 111 00 31"
String displayPhone(String? e164) {
  final d = (e164 ?? '').replaceAll(RegExp(r'\D'), '');
  final local = d.startsWith('90') && d.length == 12 ? '0${d.substring(2)}' : d;
  if (local.length != 11) return e164 ?? '';
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7, 9)} ${local.substring(9)}';
}

String phoneDigits(String? e164) => (e164 ?? '').replaceAll(RegExp(r'\D'), '');

/// m² × birim fiyat → toplam kutusu metni ("1250,5"); 1.000.000'u geçerse null.
String? meterTotal(String area, String rate) {
  final l = parseAmount(area).value;
  final r = parseAmount(rate).value;
  if (l == null || r == null) return null;
  final cents = (l * r * 100).round();
  if (cents < 0 || cents > amountMax * 100) return null;
  return amountWire(cents / 100);
}

double? meterProduct(String area, String rate) {
  final l = parseAmount(area).value;
  final r = parseAmount(rate).value;
  if (l == null || r == null) return null;
  return (l * r * 100).round() / 100;
}

String mapsHref(String address) => 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
String telHref(String? e164) => 'tel:+${phoneDigits(e164)}';
String waHref(String? e164, [String? text]) => 'https://wa.me/${phoneDigits(e164)}${text == null ? '' : '?text=${Uri.encodeComponent(text)}'}';

/// tr-TR büyük harf: "i" → "İ", "ı" → "I".
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// 0'dan başlayan yuvarlak üst sınır: 2.500 / 5.000 gibi.
double niceMax(double v) {
  if (!v.isFinite || v <= 0) return 1;
  final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final step = <double>[1, 2, 2.5, 5, 10].firstWhere((c) => c * p >= v, orElse: () => 10);
  return step * p;
}

/// Eksen yazısı: 10.000'in altında tam, üstünde kısa (25 B, 2,5 Mn).
String axisNumber(num v) {
  if (v.abs() >= 10000) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    String one(double x) => NumberFormat('#,##0.#', 'tr_TR').format(x);
    if (abs >= 1e9) return '$sign${one(abs / 1e9)} Mr';
    if (abs >= 1e6) return '$sign${one(abs / 1e6)} Mn';
    return '$sign${one(abs / 1e3)} B';
  }
  return NumberFormat('#,##0.#', 'tr_TR').format(v);
}

/// Yüzde değişim; önceki dönem sıfırsa null.
int? change(num? now, num? before) {
  if (before == null || before == 0) return null;
  return (((now ?? 0) - before) / before * 100).round();
}

/// Saat → "1,5 gün" / "18 saat".
String duration(num? hours) {
  if (hours == null) return '—';
  if (hours < 24) return '${hours.round()} saat';
  return '${NumberFormat('#,##0.#', 'tr_TR').format((hours / 24 * 10).round() / 10)} gün';
}

String percentText(num? v) => v == null ? '—' : '%$v';

/// 4.6 → "4,6"
String decimalTr(num v, [int digits = 1]) => NumberFormat('0.${'0' * digits}', 'tr_TR').format(v);
