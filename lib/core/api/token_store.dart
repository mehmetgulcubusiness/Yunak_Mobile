import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Erişim token'ı (15 dk) yalnız bellekte; yenileme token'ı güvenli depoda.
/// Yenileme her seferinde yeni bir token döner: eski artık geçmez, bu yüzden
/// cevap gelir gelmez diske yazılır.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'yunak.refreshToken';
  static const _cookieKey = 'yunak.sessionCookie';
  final FlutterSecureStorage _storage;

  String? accessToken;
  DateTime? accessExpiresAt;
  String? _refreshToken;
  bool _loaded = false;

  /// Çerez modu (sunucuda /api/mobile yoksa): web oturum çerezi "ad=değer".
  String? cookie;

  Future<void> load() async {
    await refreshToken();
    try {
      cookie = await _storage.read(key: _cookieKey);
    } catch (_) {
      cookie = null;
    }
  }

  Future<void> saveCookie(String? value) async {
    cookie = value;
    try {
      value == null ? await _storage.delete(key: _cookieKey) : await _storage.write(key: _cookieKey, value: value);
    } catch (_) {}
  }

  Future<String?> refreshToken() async {
    if (!_loaded) {
      try {
        _refreshToken = await _storage.read(key: _refreshKey);
      } catch (_) {
        _refreshToken = null;
      }
      _loaded = true;
    }
    return _refreshToken;
  }

  Future<void> save({required String accessToken, required DateTime? accessExpiresAt, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.accessExpiresAt = accessExpiresAt;
    _refreshToken = refreshToken;
    _loaded = true;
    try {
      await _storage.write(key: _refreshKey, value: refreshToken);
    } catch (_) {
      // Depo yazılamazsa oturum bu açılış boyunca bellekte sürer.
    }
  }

  Future<void> clear() async {
    accessToken = null;
    accessExpiresAt = null;
    _refreshToken = null;
    cookie = null;
    _loaded = true;
    try {
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _cookieKey);
    } catch (_) {}
  }

  /// Erişim token'ının bitmesine 60 sn'den az kaldı mı?
  bool get accessStale {
    final at = accessExpiresAt;
    if (accessToken == null || at == null) return true;
    return at.difference(DateTime.now()).inSeconds < 60;
  }
}
