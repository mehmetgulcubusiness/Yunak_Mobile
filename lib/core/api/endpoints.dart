import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';
import 'json.dart';

/// Sunucunun /api uçları. Her metot bir route'a karşılık gelir (ccs_server/src/routes/index.ts).
class Api {
  Api(this.c);
  final ApiClient c;

  late final auth = AuthApi(c);
  late final orders = OrdersApi(c);
  late final customers = CustomersApi(c);
  late final ratings = RatingsApi(c);
  late final reports = ReportsApi(c);
  late final settings = SettingsApi(c);
}

class AuthApi {
  AuthApi(this.c);
  final ApiClient c;

  Future<Json> mobileConfig() async => asJson(await c.anonymous('GET', '/api/mobile/config'));

  /// Uygulama girişi: çerez değil token döner. Cevaptaki `me` ayrıca okunur.
  Future<Me> login(String phone, String password, {String? deviceName}) async {
    final body = asJson(await c.anonymous('POST', '/api/mobile/auth/login', body: {
      'phone': phone,
      'password': password,
      if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
    }));
    await c.saveTokens(body);
    return Me(body.m('me'));
  }

  /// Çerez modu girişi (web ile aynı uç). Cevap doğrudan `me`; çerez istemcide saklanır.
  Future<Me> loginWithCookie(String phone, String password) async =>
      Me(asJson(await c.anonymous('POST', '/api/auth/login', body: {'phone': phone, 'password': password})));
  Future<void> logoutCookie() => c.post('/api/auth/logout');

  Future<Me> me() async => Me(asJson(await c.get('/api/auth/me')));

  Future<void> logout() => c.post('/api/mobile/auth/logout');
  Future<void> logoutAll() => c.post('/api/auth/logout-all');

  Future<void> register({required String business, required String name, required String phone, required String password}) =>
      c.anonymous('POST', '/api/auth/register', body: {'business': business, 'name': name, 'phone': phone, 'password': password}, origin: true);

  Future<void> changePassword(String currentPassword, String newPassword) =>
      c.post('/api/auth/password', {'currentPassword': currentPassword, 'newPassword': newPassword});

  Future<List<SessionView>> sessions() async => asJson(await c.get('/api/auth/sessions')).l('items').map(SessionView.new).toList();
  Future<void> revokeSession(String id) => c.del('/api/auth/sessions/${seg(id)}');

  Future<Json> requestDeletion(String password) async => asJson(await c.post('/api/account/deletion', {'password': password}));
  Future<void> cancelDeletion(String phone, String password) =>
      c.anonymous('POST', '/api/account/deletion/cancel', body: {'phone': phone, 'password': password}, origin: true);
}

class OrdersApi {
  OrdersApi(this.c);
  final ApiClient c;

  Future<OrderPage> list({String tab = 'open', String q = '', int page = 1, String? month}) async =>
      OrderPage(asJson(await c.get('/api/orders', query: {'tab': tab, 'q': q, 'page': page, 'month': month})));
  Future<String?> suggestedReference() async => asJson(await c.get('/api/orders/suggested-reference')).s('reference');
  Future<Json> open(Json body) async => asJson(await c.post('/api/orders', body));
  Future<Json> advance(String id, String to) async => asJson(await c.post('/api/orders/${seg(id)}/advance', {'to': to}));
  Future<void> cancel(String id) => c.post('/api/orders/${seg(id)}/cancel');
  Future<void> voidOrder(String id) => c.post('/api/orders/${seg(id)}/void');
  Future<Json> requestRating(String id) async => asJson(await c.post('/api/orders/${seg(id)}/rating-request'));
  Future<int> retry(String id) async => asJson(await c.post('/api/orders/${seg(id)}/retry')).i('requeued');
  Future<void> quote(String id, {required String amount, required String note}) =>
      c.patch('/api/orders/${seg(id)}/quote', {'amount': amount, 'note': note});
  Future<void> sendIban(String id) => c.post('/api/orders/${seg(id)}/send-iban');
  Future<void> flush() => c.post('/api/outbox/flush');
}

class CustomersApi {
  CustomersApi(this.c);
  final ApiClient c;

  Future<Paged<CustomerRow>> list({String q = '', int page = 1}) async {
    final raw = asJson(await c.get('/api/customers', query: {'q': q, 'page': page}));
    return Paged(raw, raw.l('items').map(CustomerRow.new).toList());
  }

  Future<CustomerCard> card(String id) async => CustomerCard(asJson(await c.get('/api/customers/${seg(id)}')));
  Future<dynamic> update(String id, Json form) => c.put('/api/customers/${seg(id)}', form);
  Future<dynamic> saveNote(String id, String note) => c.put('/api/customers/${seg(id)}/note', {'note': note});
  Future<void> optOut(String id) => c.post('/api/customers/${seg(id)}/opt-out');
  Future<void> optIn(String id) => c.post('/api/customers/${seg(id)}/opt-in');
  Future<void> erase(String id) => c.del('/api/customers/${seg(id)}');
  Future<void> sendIban(String id) => c.post('/api/customers/${seg(id)}/send-iban');
}

class RatingsApi {
  RatingsApi(this.c);
  final ApiClient c;

  Future<RatingPage> list({String filter = 'all', String q = '', int page = 1}) async =>
      RatingPage(asJson(await c.get('/api/ratings', query: {'filter': filter == 'all' ? '' : filter, 'q': q, 'page': page})));
  Future<void> resolve(String id) => c.post('/api/ratings/${seg(id)}/resolve');
}

class ReportsApi {
  ReportsApi(this.c);
  final ApiClient c;

  Future<Dashboard> dashboard() async => Dashboard(asJson(await c.get('/api/dashboard')));
  Future<Json> cash(String period) async => asJson(await c.get('/api/cash', query: {'period': period == 'month' ? '' : period}));
  Future<({Uint8List bytes, String? fileName})> cashExport(String period) => c.download('/api/cash/export', query: {'period': period});
  Future<Json> analytics(int range) async => asJson(await c.get('/api/analytics', query: {'range': range}));
  Future<Json> routeSheet() async => asJson(await c.get('/api/route-sheet'));
}

class SettingsApi {
  SettingsApi(this.c);
  final ApiClient c;

  Future<Json> get() async => asJson(await c.get('/api/settings'));
  Future<void> update(Json form) => c.put('/api/settings', form);
  Future<List<TeamMember>> team() async => asJson(await c.get('/api/team')).l('items').map(TeamMember.new).toList();
  Future<void> addMember(Json form) => c.post('/api/team', form);
  Future<void> toggleMember(String id) => c.post('/api/team/${seg(id)}/toggle');
  Future<void> resetPassword(String id, String password) => c.post('/api/team/${seg(id)}/password', {'password': password});
}
