import 'dart:convert';
import 'dart:typed_data';

import 'package:css_mobile/core/api/api_client.dart';
import 'package:css_mobile/core/api/endpoints.dart';
import 'package:css_mobile/core/api/token_store.dart';
import 'package:css_mobile/core/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// İstekleri kaydeden, sunucu gibi cevap veren sahte bağdaştırıcı.
class FakeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    ResponseBody json(Object body, {int status = 200, Map<String, List<String>> headers = const {}}) =>
        ResponseBody.fromString(jsonEncode(body), status, headers: {'content-type': ['application/json'], ...headers});
    switch (options.path) {
      case '/api/auth/login':
        return json({'user': {'id': 'u1', 'name': 'Ayşe Yılmaz', 'role': 'admin', 'phone': '+905321110031'}},
            headers: {'set-cookie': ['ccs_session=abc.def; Path=/; HttpOnly; Secure; SameSite=Lax']});
      case '/api/auth/logout':
        return ResponseBody.fromString('', 204, headers: {'set-cookie': ['ccs_session=; Path=/; Max-Age=0']});
      default:
        return json({'ok': true});
    }
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('çerez modunda giriş çerezi saklar, sonraki isteklerde gönderir, çıkışta siler', () async {
    final adapter = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://yunakhaliyikama.com.tr', validateStatus: (_) => true))..httpClientAdapter = adapter;
    final tokens = TokenStore();
    final client = ApiClient(tokens, dio: dio)..cookieMode = true;
    final api = Api(client);

    final me = await api.auth.loginWithCookie('05321110031', 'abcdefg1');
    expect(me.userName, 'Ayşe Yılmaz');
    expect(tokens.cookie, 'ccs_session=abc.def');
    expect(adapter.requests.last.headers['origin'], AppConfig.webOrigin);

    await client.get('/api/orders');
    final get = adapter.requests.last;
    expect(get.headers['cookie'], 'ccs_session=abc.def');
    expect(get.headers['authorization'], isNull);
    expect(get.headers['origin'], isNull);

    await client.post('/api/orders/1/advance', {'to': 'washing'});
    expect(adapter.requests.last.headers['origin'], AppConfig.webOrigin);

    await api.auth.logoutCookie();
    expect(tokens.cookie, isNull);
  });
}
