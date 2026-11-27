import 'package:css_mobile/core/config.dart';
import 'package:css_mobile/ui/route/route_page.dart';
import 'package:css_mobile/ui/shell/ops_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sürüm karşılaştırma', () {
    expect(compareVersions('1.4.0', '1.10.0') < 0, isTrue);
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('2.0.0', '1.9.9') > 0, isTrue);
  });
  test('X-Client başlığı kalıba uyar', () {
    expect(RegExp(r'^yunak-(android|ios)/\d{1,4}\.\d{1,4}\.\d{1,4}$').hasMatch(AppConfig.clientHeader), isTrue);
  });
  test('menü bölümü', () {
    expect(sectionOf('/ops'), 'desk');
    expect(sectionOf('/ops/arsiv'), 'archive');
    expect(sectionOf('/ops/kasa'), 'cash');
    expect(sectionOf('/ops/sifre'), 'password');
  });
  test('sayfa no', () {
    expect(readPage(null), 1);
    expect(readPage('0'), 1);
    expect(readPage('abc'), 1);
    expect(readPage('3'), 3);
  });
  test('rota linki ilk 10 durak', () {
    final href = routeHref([for (var i = 1; i <= 12; i++) 'Adres $i']);
    final uri = Uri.parse(href);
    expect(uri.queryParameters['destination'], 'Adres 10');
    expect(uri.queryParameters['waypoints']!.split('|').length, 9);
  });
}
