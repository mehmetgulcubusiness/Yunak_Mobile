import 'dart:async';

/// Uygulama geneli API olayları. Oturum denetleyicisi ve bağlantı şeridi dinler.
sealed class ApiEvent {
  const ApiEvent();
}

/// Oturum düştü (401 ve yenileme de başarısız).
class Unauthenticated extends ApiEvent {
  const Unauthenticated();
}

/// Firma onay bekliyor / askıda / reddedildi / kapanıyor (403 tenant_*).
class Blocked extends ApiEvent {
  const Blocked(this.code, this.message);
  final String code;
  final String message;
}

class Offline extends ApiEvent {
  const Offline();
}

class Online extends ApiEvent {
  const Online();
}

/// Uygulama sürümü sunucunun kabul ettiği en düşük sürümün altında (426).
class Outdated extends ApiEvent {
  const Outdated(this.minVersion, this.updateUrl);
  final String? minVersion;
  final String? updateUrl;
}

class ApiEvents {
  ApiEvents._();
  static final _controller = StreamController<ApiEvent>.broadcast();
  static Stream<ApiEvent> get stream => _controller.stream;
  static void emit(ApiEvent e) => _controller.add(e);
}
