import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Canlı site: web paneli `/api` isteklerini sunucuya aktarır (API_UPSTREAM). Uygulama da aynı
/// adrese bağlanır; sunucunun CSRF koruması bu adresi (PUBLIC_BASE_URL) tanır.
/// Başka bir sunucu için: `--dart-define=API_BASE_URL=http://10.0.2.2:8080` (emülatörden yerel ccs_server).
const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://yunakhaliyikama.com.tr');

/// Müşteri puan sayfası ve web paneli için web kökü. Boşsa API kökü kullanılır.
const String _webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: '');

class AppConfig {
  AppConfig._();

  static String get apiBaseUrl => _apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  static String get webBaseUrl => (_webBaseUrl.isEmpty ? _apiBaseUrl : _webBaseUrl).replaceAll(RegExp(r'/+$'), '');

  /// `Origin` başlığı: yalnız oturumsuz POST'larda (kayıt, silme talebini geri alma) sunucunun
  /// CSRF korumasından geçmek için. Bkz. docs/11-yol-haritasi.md §3.
  static String get webOrigin {
    final uri = Uri.parse(webBaseUrl);
    return uri.hasPort && uri.port != 80 && uri.port != 443 ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }

  static String get platform {
    if (kIsWeb) return 'android';
    try {
      return Platform.isIOS ? 'ios' : 'android';
    } catch (_) {
      return 'android';
    }
  }

  /// Uygulama sürümü (`package_info_plus` ile açılışta doldurulur). Kalıp MAJOR.MINOR.PATCH.
  static String version = '1.0.0';

  /// `X-Client: yunak-android/1.0.0`
  static String get clientHeader => 'yunak-$platform/$version';

  /// Ortak tezgâh cihazında açık kalan oturum bu süre hareketsiz kalınca kapanır.
  static const idleTimeout = Duration(minutes: 30);
}

/// "1.4.0" < "1.10.0" gibi sayısal karşılaştırma. Bozuk sürüm 0 sayılır.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 3; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l - r;
  }
  return 0;
}
