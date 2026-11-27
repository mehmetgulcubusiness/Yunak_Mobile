import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/api_events.dart';
import '../api/endpoints.dart';
import '../api/token_store.dart';
import '../config.dart';
import '../models/models.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStoreProvider)));
final apiProvider = Provider<Api>((ref) => Api(ref.watch(apiClientProvider)));

enum SessionStatus { loading, anonymous, blocked, ready, outdated }

/// Giriş ekranındaki bilgi kutusu.
enum LoginNotice { none, registered, expired, idle, passwordChanged }

class BlockInfo {
  const BlockInfo(this.code, this.message);
  final String code;
  final String message;
}

class SessionState {
  const SessionState({
    required this.status,
    this.me,
    this.block,
    this.notice = LoginNotice.none,
    this.from,
    this.updateUrl,
    this.minVersion,
    this.bootOffline = false,
  });

  final SessionStatus status;
  final Me? me;
  final BlockInfo? block;
  final LoginNotice notice;

  /// 401 ile düşüldüğünde dönülecek konum.
  final String? from;
  final String? updateUrl;
  final String? minVersion;
  final bool bootOffline;

  SessionState copy({
    SessionStatus? status,
    Me? me,
    BlockInfo? block,
    LoginNotice? notice,
    String? from,
    String? updateUrl,
    String? minVersion,
    bool? bootOffline,
  }) =>
      SessionState(
        status: status ?? this.status,
        me: me ?? this.me,
        block: block ?? this.block,
        notice: notice ?? this.notice,
        from: from ?? this.from,
        updateUrl: updateUrl ?? this.updateUrl,
        minVersion: minVersion ?? this.minVersion,
        bootOffline: bootOffline ?? this.bootOffline,
      );
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Konumu router bilir; oturum düştüğünde nereye dönüleceğini buradan okuruz.
String Function() currentLocation = () => '/ops';

class SessionController extends Notifier<SessionState> {
  StreamSubscription<ApiEvent>? _events;

  Api get _api => ref.read(apiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  SessionState build() {
    _events = ApiEvents.stream.listen(_onEvent);
    ref.onDispose(() => _events?.cancel());
    scheduleMicrotask(boot);
    return const SessionState(status: SessionStatus.loading);
  }

  void _onEvent(ApiEvent e) {
    switch (e) {
      case Unauthenticated():
        if (state.status == SessionStatus.ready) {
          state = SessionState(status: SessionStatus.anonymous, notice: LoginNotice.expired, from: currentLocation());
        }
      case Blocked(:final code, :final message):
        if (state.status == SessionStatus.ready || state.status == SessionStatus.loading) {
          state = SessionState(status: SessionStatus.blocked, block: BlockInfo(code, message), me: state.me);
        }
      case Outdated(:final minVersion, :final updateUrl):
        state = SessionState(status: SessionStatus.outdated, minVersion: minVersion, updateUrl: updateUrl);
      case Online():
        if (state.bootOffline && state.status == SessionStatus.anonymous) unawaited(boot());
      case Offline():
        break;
    }
  }

  Future<void> boot() async {
    // 1) Sürüm kontrolü. Sunucuda mobil uçlar yoksa (cevap sürüm bilgisi değilse)
    //    web gibi çerezli oturuma geçilir. Ağ hatası açılışı engellemez.
    final client = ref.read(apiClientProvider);
    try {
      final config = await _api.auth.mobileConfig();
      client.cookieMode = config['minVersion'] is! String;
      final min = config['minVersion'];
      if (min is String && compareVersions(AppConfig.version, min) < 0) {
        state = SessionState(status: SessionStatus.outdated, minVersion: min, updateUrl: config['updateUrl'] as String?);
        return;
      }
    } on ApiError catch (e) {
      if (e.status == 426) return;
      client.cookieMode = !e.isNetwork;
    }
    if (state.status == SessionStatus.outdated) return;
    await _tokens.load();

    // 2) Kayıtlı oturum.
    if (client.cookieMode) {
      if (_tokens.cookie == null) {
        state = const SessionState(status: SessionStatus.anonymous);
        return;
      }
      try {
        state = SessionState(status: SessionStatus.ready, me: await _api.auth.me());
      } on ApiError catch (e) {
        if (e.isTenantBlock) {
          state = SessionState(status: SessionStatus.blocked, block: BlockInfo(e.code, e.message));
        } else if (e.isNetwork) {
          state = const SessionState(status: SessionStatus.anonymous, bootOffline: true);
        } else {
          await _tokens.clear();
          state = const SessionState(status: SessionStatus.anonymous);
        }
      }
      return;
    }
    if (await _tokens.refreshToken() == null) {
      state = const SessionState(status: SessionStatus.anonymous);
      return;
    }
    try {
      await ref.read(apiClientProvider).refreshSession();
      final me = await _api.auth.me();
      state = SessionState(status: SessionStatus.ready, me: me);
    } on ApiError catch (e) {
      if (state.status == SessionStatus.outdated) return;
      if (e.isTenantBlock) {
        state = SessionState(status: SessionStatus.blocked, block: BlockInfo(e.code, e.message));
      } else if (e.isNetwork) {
        state = const SessionState(status: SessionStatus.anonymous, bootOffline: true);
      } else {
        await _tokens.clear();
        state = const SessionState(status: SessionStatus.anonymous);
      }
    }
  }

  Future<void> signIn(String phone, String password) async {
    final me = ref.read(apiClientProvider).cookieMode
        ? await _api.auth.loginWithCookie(phone, password)
        : await _api.auth.login(phone, password, deviceName: await _deviceName());
    state = SessionState(status: SessionStatus.ready, me: me);
  }

  Future<void> signOut({LoginNotice notice = LoginNotice.none}) async {
    try {
      if (ref.read(apiClientProvider).cookieMode) {
        if (_tokens.cookie != null) await _api.auth.logoutCookie();
      } else if (_tokens.accessToken != null || await _tokens.refreshToken() != null) {
        await _api.auth.logout();
      }
    } catch (_) {
      // Çıkış hatası yutulur; yerel token her durumda silinir.
    }
    await _tokens.clear();
    state = SessionState(status: SessionStatus.anonymous, notice: notice);
  }

  /// Sunucu tüm oturumları zaten kapattı (logout-all, hesap silme): yalnız yerel temizlik.
  Future<void> dropLocal({LoginNotice notice = LoginNotice.none}) async {
    await _tokens.clear();
    state = SessionState(status: SessionStatus.anonymous, notice: notice);
  }

  /// `/me` yeniden okunur (ayarlar kaydedilince firma adı, WhatsApp durumu değişir).
  Future<void> refresh() async {
    try {
      final me = await _api.auth.me();
      if (state.status == SessionStatus.ready) state = state.copy(me: me);
    } catch (_) {}
  }

  void setNotice(LoginNotice notice) => state = state.copy(notice: notice);

  Future<String?> _deviceName() async {
    if (kIsWeb) return null;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final n = '${a.manufacturer} ${a.model}'.trim();
        return n.length > 60 ? n.substring(0, 60) : n;
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.name.length > 60 ? i.name.substring(0, 60) : i.name;
      }
    } catch (_) {}
    return null;
  }
}
