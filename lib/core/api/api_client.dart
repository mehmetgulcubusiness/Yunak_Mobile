import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config.dart';
import 'api_error.dart';
import 'api_events.dart';
import 'json.dart';
import 'token_store.dart';

/// Yol parçası: kimlikler yol parametresinde her zaman kodlanır.
String seg(Object? v) => Uri.encodeComponent('${v ?? ''}');

/// Bu uçların 401 cevabı "oturum düştü" anlamına gelmez (yanlış şifre, oturum yok).
const _quiet401 = ['/api/auth/login', '/api/auth/me', '/api/auth/logout', '/api/auth/password', '/api/mobile/'];

/// Tek HTTP istemcisi (web'deki `api/http.js` karşılığı).
///
///  * Her istekte `X-Client: yunak-android/1.0.0`.
///  * Oturumlu isteklerde `Authorization: Bearer <accessToken>`; token bitmek
///    üzereyse önce yenilenir. `401 unauthenticated` gelirse bir kez yenileyip
///    isteği tekrarlar; yenileme de olmazsa `Unauthenticated` olayı yayılır.
///  * Aynı anda gelen 401'ler tek bir yenileme isteğini paylaşır.
class ApiClient {
  ApiClient(this.tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ));

  final Dio _dio;
  final TokenStore tokens;
  Future<void>? _refreshing;
  bool _offline = false;

  /// Sunucuda mobil uçlar yoksa web gibi çerezli oturum kullanılır (açılışta belirlenir).
  bool cookieMode = false;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => request('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body = const {}]) => request('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body = const {}]) => request('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body = const {}]) => request('PATCH', path, body: body);
  Future<dynamic> del(String path) => request('DELETE', path);

  /// Oturumsuz uçlar (giriş, kayıt, yenileme). `origin`: CSRF korumalı oturumsuz POST'lar için.
  Future<dynamic> anonymous(String method, String path, {Object? body, bool origin = false}) =>
      request(method, path, body: body, auth: false, origin: origin);

  /// Dosya indirme (Kasa › Excel). Gövde bayt olarak döner.
  Future<({Uint8List bytes, String? fileName})> download(String path, {Map<String, Object?>? query}) async {
    final res = await _send('GET', path, query: query, auth: true, bytes: true);
    final data = res.data;
    final bytes = data is Uint8List ? data : Uint8List.fromList((data as List).cast<int>());
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''', caseSensitive: false).firstMatch(disposition);
    return (bytes: bytes, fileName: match == null ? null : Uri.decodeComponent(match.group(1)!));
  }

  Future<dynamic> request(String method, String path,
      {Object? body, Map<String, Object?>? query, bool auth = true, bool origin = false}) async {
    final res = await _send(method, path, body: body, query: query, auth: auth, origin: origin);
    return _decode(res);
  }

  Future<Response<dynamic>> _send(String method, String path,
      {Object? body, Map<String, Object?>? query, bool auth = true, bool origin = false, bool bytes = false, bool retried = false}) async {
    if (auth && tokens.accessStale && await tokens.refreshToken() != null) {
      try {
        await refreshSession();
      } on ApiError catch (e) {
        if (!e.isNetwork) return _sessionLost(path, e);
        rethrow;
      }
    }
    final res = await _raw(method, path, body: body, query: query, auth: auth, origin: origin, bytes: bytes);
    if (res.statusCode == 401 && auth && !retried) {
      final error = _errorOf(res);
      if (error.code == 'unauthenticated' && await tokens.refreshToken() != null) {
        try {
          await refreshSession();
        } on ApiError catch (e) {
          if (!e.isNetwork) return _sessionLost(path, error);
          rethrow;
        }
        return _send(method, path, body: body, query: query, auth: auth, origin: origin, bytes: bytes, retried: true);
      }
    }
    if (bytes && (res.statusCode ?? 0) >= 400) {
      // Hata gövdesi bayt geldi; JSON olarak çöz.
      final text = utf8.decode(res.data is List<int> ? res.data as List<int> : <int>[], allowMalformed: true);
      throw _failure(path, res.statusCode ?? 0, _payload(text), res);
    }
    return res;
  }

  Never _sessionLost(String path, ApiError error) {
    unawaited(tokens.clear());
    if (!_quiet401.any(path.startsWith)) ApiEvents.emit(const Unauthenticated());
    throw ApiError(401, 'unauthenticated', error.message.isEmpty ? 'Oturum açın.' : error.message, error.extra);
  }

  Future<Response<dynamic>> _raw(String method, String path,
      {Object? body, Map<String, Object?>? query, required bool auth, bool origin = false, bool bytes = false}) async {
    final headers = <String, Object>{
      'accept': 'application/json',
      'x-client': AppConfig.clientHeader,
      if (body != null) 'content-type': 'application/json',
      if (!cookieMode && auth && tokens.accessToken != null) 'authorization': 'Bearer ${tokens.accessToken}',
      if (cookieMode && tokens.cookie != null) 'cookie': tokens.cookie!,
      // Çerezli oturumda durum değiştiren istekler sitenin kendi adresinden gelmeli (CSRF koruması).
      if (origin || (cookieMode && method != 'GET')) 'origin': AppConfig.webOrigin,
    };
    final params = <String, dynamic>{};
    query?.forEach((k, v) {
      if (v == null || v == '') return;
      params[k] = '$v';
    });
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body == null ? null : jsonEncode(body),
        queryParameters: params.isEmpty ? null : params,
        options: Options(method: method, headers: headers, responseType: bytes ? ResponseType.bytes : ResponseType.plain),
      );
      if (_offline) {
        _offline = false;
        ApiEvents.emit(const Online());
      }
      if (cookieMode) await _storeCookie(res.headers['set-cookie']);
      return res;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      _offline = true;
      ApiEvents.emit(const Offline());
      throw ApiError.network();
    }
  }

  /// Sunucunun verdiği (ya da sildiği) oturum çerezini saklar.
  Future<void> _storeCookie(List<String>? headers) async {
    if (headers == null || headers.isEmpty) return;
    for (final h in headers) {
      final pair = h.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final cleared = pair.substring(eq + 1).isEmpty || RegExp(r'max-age=0(;|$)', caseSensitive: false).hasMatch(h.replaceAll(' ', ''));
      await tokens.saveCookie(cleared ? null : pair);
    }
  }

  dynamic _payload(Object? text) {
    if (text is! String || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  ApiError _errorOf(Response<dynamic> res) {
    final data = res.data;
    final payload = _payload(data is List<int> ? utf8.decode(data, allowMalformed: true) : data);
    final error = asJson(asJson(payload)['error']);
    return ApiError(res.statusCode ?? 0, error.s('code') ?? 'http_error', error.s('message') ?? 'İşlem yapılamadı.', error);
  }

  dynamic _decode(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    if (status == 204) return null;
    final payload = _payload(res.data);
    if (status >= 200 && status < 300) return payload;
    throw _failure(res.requestOptions.path, status, payload, res);
  }

  ApiError _failure(String path, int status, dynamic payload, Response<dynamic> res) {
    final error = Map<String, dynamic>.from(asJson(asJson(payload)['error']));
    if (status == 429 && error['retryAfterSeconds'] is! num) {
      final header = int.tryParse(res.headers.value('retry-after') ?? '');
      if (header != null && header > 0) error['retryAfterSeconds'] = header;
    }
    final failure = ApiError(status, error.s('code') ?? 'http_error', error.s('message') ?? 'İşlem yapılamadı.', error);
    if (status == 401 && !_quiet401.any(path.startsWith)) {
      unawaited(tokens.clear());
      ApiEvents.emit(const Unauthenticated());
    }
    if (failure.isTenantBlock) ApiEvents.emit(Blocked(failure.code, failure.message));
    if (status == 426) ApiEvents.emit(Outdated(error.s('minVersion'), error.s('updateUrl')));
    return failure;
  }

  /// Yenileme token'ı ile yeni bir çift alır. Eşzamanlı çağrılar aynı isteği bekler.
  Future<void> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final refresh = await tokens.refreshToken();
    if (refresh == null) throw ApiError(401, 'unauthenticated', 'Oturum açın.');
    final res = await _raw('POST', '/api/mobile/auth/refresh', body: {'refreshToken': refresh}, auth: false);
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      await saveTokens(asJson(_payload(res.data)));
      return;
    }
    final failure = _failure('/api/mobile/auth/refresh', status, _payload(res.data), res);
    if (status == 401 || status == 403 || status == 400) await tokens.clear();
    throw failure;
  }

  Future<void> saveTokens(Json body) async {
    final access = body.s('accessToken');
    final refresh = body.s('refreshToken');
    if (access == null || refresh == null) throw ApiError(500, 'bad_tokens', 'Sunucu oturum bilgisini döndürmedi.');
    await tokens.save(
      accessToken: access,
      accessExpiresAt: DateTime.tryParse(body.str('accessExpiresAt')),
      refreshToken: refresh,
    );
  }
}
