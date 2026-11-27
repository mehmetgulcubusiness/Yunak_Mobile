import '../api/json.dart';

class Tenant {
  Tenant(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get name => raw.str('name');
  String get phone => raw.str('phone');
  String get status => raw.str('status');
  bool get whatsappBound => raw.b('whatsappBound');
  bool get setupGoogleReview => raw.m('setup').b('googleReview');
  bool get setupIban => raw.m('setup').b('iban');
}

class Me {
  Me(this.raw);
  final Json raw;
  Json get _user => raw.m('user');
  String get userId => _user.str('id');
  String get userName => _user.str('name');
  String get role => _user.str('role');
  String get phone => _user.str('phone');
  bool get isOwner => _user.b('isOwner');
  Tenant? get tenant => raw.mOrNull('tenant') == null ? null : Tenant(raw.m('tenant'));
  int get openCrises => raw.i('openCrises');
  bool get isManager => role == 'admin' || role == 'super_admin';
  String get firstName => userName.split(' ').first;
}

class Dashboard {
  Dashboard(this.raw);
  final Json raw;
  Json get kpis => raw.m('kpis');
  Json get tabs => raw.m('tabs');
  Json get queue => raw.m('queue');
  int get openCrises => raw.i('openCrises');
  int get overdue => raw.i('overdue');
  int get stuck => queue.i('failed') + queue.i('uncertain');
  num? get revenueToday => kpis.n('revenueToday');
}

class Move {
  const Move(this.to);
  final String to;
}

class DeskOrder {
  DeskOrder(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get customerId => raw.str('customerId');
  String get reference => raw.str('reference');
  String get serviceType => raw.str('serviceType');
  String get customerName => raw.str('customerName');
  String get phone => raw.str('phone');
  String? get address => raw.s('address');
  String? get deskNote => raw.s('deskNote');
  String get status => raw.str('status');
  bool get voided => raw.b('voided');
  String? get createdAt => raw.s('createdAt');
  String? get deliveredAt => raw.s('deliveredAt');
  num? get amount => raw.n('amount');
  String? get actorName => raw.s('actorName');
  Json? get feedback => raw.mOrNull('feedback');
  bool get whatsappStuck => raw.b('whatsappStuck');
  List<Move> get moves => raw.l('moves').map((m) => Move(m.str('to'))).where((m) => m.to.isNotEmpty).toList();
  bool get cancellable => raw.b('cancellable');
  bool get voidable => raw.b('voidable');
  String? get previewToken => raw.s('previewToken');
}

class DaySummary {
  DaySummary(this.raw);
  final Json raw;
  String get day => raw.str('day');
  int get count => raw.i('count');
  num? get totalTry => raw.n('totalTry');
}

class Paged<T> {
  Paged(this.raw, this.items);
  final Json raw;
  final List<T> items;
  int get total => raw.i('total');
  int get page => raw.i('page', 1);
}

class OrderPage extends Paged<DeskOrder> {
  OrderPage(Json raw) : super(raw, raw.l('items').map(DeskOrder.new).toList());
  List<DaySummary> get days => raw.l('days').map(DaySummary.new).toList();
  List<Json> get months => raw.l('months');
}

class CustomerRow {
  CustomerRow(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get name => raw.str('name');
  String get phone => raw.str('phone');
  String? get address => raw.s('address');
  bool get optedOut => raw.b('optedOut');
  int get orderCount => raw.i('orderCount');
  num? get totalTry => raw.n('totalTry');
  String? get lastOrderAt => raw.s('lastOrderAt');
}

class CustomerSlip {
  CustomerSlip(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get reference => raw.str('reference');
  String get serviceType => raw.str('serviceType');
  String? get createdAt => raw.s('createdAt');
  num? get amount => raw.n('amount');
  String get status => raw.str('status');
  bool get voided => raw.b('voided');
  String? get note => raw.s('note');
  String? get actorName => raw.s('actorName');
}

class CustomerCard {
  CustomerCard(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get name => raw.str('name');
  String get phone => raw.str('phone');
  String? get address => raw.s('address');
  String? get note => raw.s('note');
  bool get optedOut => raw.b('optedOut');
  int get orderCount => raw.i('orderCount');
  num? get totalTry => raw.n('totalTry');
  int? get lastStars => raw.iOrNull('lastStars');
  List<CustomerSlip> get orders => raw.l('orders').map(CustomerSlip.new).toList();
  CustomerCard merge(Json patch) => CustomerCard({...raw, ...patch});
}

class RatingRow {
  RatingRow(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get customerName => raw.str('customerName');
  String get phone => raw.str('phone');
  String get reference => raw.str('reference');
  String get serviceType => raw.str('serviceType');
  num get stars => raw.n('stars') ?? 0;
  String get route => raw.str('route');
  bool get resolved => raw.b('resolved');
  String? get submittedAt => raw.s('submittedAt');
  List<String> get reasons => raw.strings('reasons');
  String? get note => raw.s('note');
}

class RatingPage extends Paged<RatingRow> {
  RatingPage(Json raw) : super(raw, raw.l('items').map(RatingRow.new).toList());
  Json get summary => raw.m('summary');
}

class TeamMember {
  TeamMember(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get name => raw.str('name');
  String get phone => raw.str('phone');
  String get role => raw.str('role');
  bool get active => raw.b('active');
  bool get canToggle => raw.b('canToggle');
  bool get canDelete => raw.b('canDelete');
  bool get canResetPassword => raw.b('canResetPassword');
}

class RouteStop {
  RouteStop(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get reference => raw.str('reference');
  String get customerName => raw.str('customerName');
  String get phone => raw.str('phone');
  String get address => (raw.s('address') ?? '').trim();
  String get serviceType => raw.str('serviceType');
  String? get createdAt => raw.s('createdAt');
  num? get amount => raw.n('amount');
  String? get note => raw.s('note');
  int get daysLate => raw.i('daysLate');
}

class SessionView {
  SessionView(this.raw);
  final Json raw;
  String get id => raw.str('id');
  String get kind => raw.str('kind');
  String? get platform => raw.s('platform');
  String? get deviceName => raw.s('deviceName');
  String? get clientVersion => raw.s('clientVersion');
  String? get createdAt => raw.s('createdAt');
  String? get lastSeenAt => raw.s('lastSeenAt');
  bool get current => raw.b('current');
}
