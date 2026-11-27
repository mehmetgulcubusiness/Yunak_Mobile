import 'dart:convert';
import 'dart:io';

import 'package:css_mobile/core/api/api_error.dart';
import 'package:css_mobile/core/format/format.dart';
import 'package:css_mobile/core/validation/validate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final cases = jsonDecode(File('test/contract_cases.json').readAsStringSync()) as Map<String, dynamic>;
  List<List<dynamic>> rows(String key) => (cases[key] as List).map((e) => e as List<dynamic>).toList();

  setUpAll(() async => initializeDateFormatting('tr_TR'));

  group('sözleşme vakaları', () {
    test('telefon', () {
      for (final c in rows('phone')) {
        expect(parsePhone(c[0] as String), c[1], reason: '${c[0]}');
      }
    });
    test('ad', () {
      for (final c in rows('personName')) {
        expect(normalizePersonName(c[0] as String), c[1], reason: '${c[0]}');
      }
    });
    test('fiş no', () {
      for (final c in rows('reference')) {
        expect(checkReference(c[0] as String).value, c[1], reason: '${c[0]}');
      }
    });
    test('tutar', () {
      for (final c in rows('amount')) {
        final o = parseAmount(c[0] as String);
        if (c[1] == 'empty') {
          expect(o.value, isNull);
          expect(o.error, isNull);
        } else if (c[1] == null) {
          expect(o.error, isNotNull, reason: '${c[0]}');
        } else {
          expect(o.value, (c[1] as num).toDouble(), reason: '${c[0]}');
        }
      }
    });
    test('IBAN', () {
      for (final c in rows('iban')) {
        expect(checkIban(c[0] as String).value, c[1], reason: '${c[0]}');
      }
    });
    test('şifre', () {
      for (final c in rows('password')) {
        expect(checkNewPassword(c[0] as String, '05321110031').error == null, c[1], reason: '${c[0]}');
      }
    });
    test('Google linki', () {
      for (final c in rows('googleUrl')) {
        expect(checkGoogleUrl(c[0] as String).error == null, c[1], reason: '${c[0]}');
      }
    });
    test('İstanbul günü', () {
      for (final c in rows('istanbulDay')) {
        expect(istanbulDayKey(c[0] as String), c[1], reason: '${c[0]}');
      }
    });
  });

  group('yazarken biçimlendirme', () {
    test('telefon maskesi', () {
      expect(maskPhone('05321110031'), '0532 111 00 31');
      expect(maskPhone('+90 532 111 00 31'), '0532 111 00 31');
      expect(maskPhone('5321'), '0532 1');
      expect(maskPhone('053211100319999'), '0532 111 00 31');
    });
    test('fiş no', () {
      expect(filterReference('hkişğü-1'), 'HKISGU-1');
      expect(filterReference('fi 1/2'), 'FI12');
    });
    test('IBAN maskesi', () {
      expect(maskIban('330006100519786457841326'), 'TR33 0006 1005 1978 6457 8413 26');
    });
    test('tutar', () {
      expect(formatAmount(1250), '1.250,00');
      expect(amountWire(1250.5), '1250,5');
      expect(amountWire(1250.05), '1250,05');
      expect(amountWire(900), '900');
    });
    test('gösterim numarası', () {
      expect(checkPublicPhone('0216 123 45 67').error, isNull);
      expect(checkPublicPhone('444 12 34').error, isNull);
      expect(checkPublicPhone('0216 abc').error, isNotNull);
    });
  });

  group('sunucu hatası → alan', () {
    test('field önce gelir', () {
      expect(fieldOfError(ApiError(400, 'invalid_phone', 'x', {'field': 'alertPhone'})), 'alertPhone');
    });
    test('koddan eşler', () {
      expect(fieldOfError(ApiError(400, 'settings_iban', 'x')), 'ibanNumber');
      expect(fieldOfError(ApiError(409, 'reference_taken', 'x')), 'reference');
    });
    test('form eşlemesi', () {
      expect(fieldOfError(ApiError(400, 'invalid_business_name', 'x', {'field': 'business'}), {'business': 'name'}), 'name');
    });
  });

  group('biçim', () {
    test('para', () {
      expect(money(1250), '1.250 ₺');
      expect(money(1250.5), '1.250,50 ₺');
      expect(money(null), isNull);
      expect(amountField(1250.5), '1.250,50');
    });
    test('telefon', () {
      expect(displayPhone('+905321110031'), '0532 111 00 31');
      expect(phoneDigits('+905321110031'), '905321110031');
    });
    test('tarih', () {
      expect(formatDay('2026-11-27T11:05:00Z'), '27 Kas 2026');
      expect(formatStamp('2026-11-27T11:05:00Z'), '27.11.2026 14:05');
      expect(formatToday('2026-11-27T11:05:00Z'), '27 Kasım Cuma');
      expect(monthLabel('2026-11'), 'Kasım 2026');
      expect(formatDay(null), '');
      expect(formatDay('bozuk'), '');
      expect(dayHeading('2026-11-02', DateTime.utc(2026, 11, 27)), '2 Kasım Pazartesi');
      expect(dayHeading('2026-11-27', DateTime.utc(2026, 11, 27, 10)), 'Bugün');
      expect(dayHeading('2026-11-26', DateTime.utc(2026, 11, 27, 10)), 'Dün');
    });
    test('selam', () {
      expect(greeting(DateTime.utc(2026, 11, 27, 6)), 'Günaydın');
      expect(greeting(DateTime.utc(2026, 11, 27, 12)), 'İyi günler');
      expect(greeting(DateTime.utc(2026, 11, 27, 18)), 'İyi akşamlar');
    });
    test('metre hesabı', () {
      expect(meterTotal('12,5', '80'), '1000');
      expect(formatAmount(parseAmount(meterTotal('12,5', '80')).value), '1.000,00');
      expect(meterTotal('2000', '1000'), isNull);
    });
    test('eksen', () {
      expect(axisNumber(25000), '25 B');
      expect(axisNumber(2500000), '2,5 Mn');
      expect(axisNumber(1250.5), '1.250,5');
      expect(niceMax(4300), 5000);
    });
    test('tr büyük harf', () {
      expect(trUpper('ismail ılgın'), 'İSMAİL ILGIN');
    });
  });
}
