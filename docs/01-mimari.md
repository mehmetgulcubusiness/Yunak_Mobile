# 01 — Mimari

## 1. Teknoloji eşlemesi

| Konu | React client | Flutter önerisi |
| --- | --- | --- |
| Router | `react-router-dom` v7 | `go_router` (`ShellRoute` + `redirect`) |
| Durum | React state + Context | `flutter_riverpod` (veya `riverpod_annotation`) |
| HTTP | `fetch` sarmalayıcı (`api/http.js`) | `dio` + interceptor |
| Oturum | HttpOnly çerez `wpqr_session` | Bearer token; `refreshToken` → `flutter_secure_storage` |
| Font | `@fontsource/inter` (self-host) | `assets/fonts/Inter-*.ttf` (400/500/600/700), Google Fonts ağdan **çekilmez** (KVKK) |
| Biçim | `Intl.NumberFormat("tr-TR")`, `Intl.DateTimeFormat(…Europe/Istanbul)` | `intl` (`tr_TR`) + `timezone` paketi (`Europe/Istanbul`) |
| Dış linkler | `<a href="tel:">`, `wa.me`, Google Maps | `url_launcher` (`LaunchMode.externalApplication`) |
| Grafik | Elle yazılmış SVG/CSS (`components/charts.jsx`) | `fl_chart` (bar, line) + elle `GridView` ısı haritası |
| Yazdırma | `window.print()` + `PrintSlip` | `printing` + `pdf` |
| Excel | `<a download href="/api/cash/export">` | Dio ile indir → `path_provider` → `share_plus` |
| Sürüm bilgisi | `/api/health.version` | `package_info_plus` → `X-Client` başlığı; `/api/mobile/config` |
| Cihaz adı | — | `device_info_plus` (login'de `deviceName`) |
| Bağlantı | `navigator.onLine` + API ağ hatası | `connectivity_plus` + Dio ağ hatası |
| Test | Vitest, Playwright | `flutter_test`, `integration_test` |

## 2. Klasör yapısı

```text
lib/
├─ main.dart                      runApp(ProviderScope(child: YunakApp()))
├─ app.dart                       MaterialApp.router, tema, locale tr_TR
├─ core/
│  ├─ api/
│  │  ├─ api_client.dart          Dio, baseUrl, X-Client, Bearer, 401→refresh, hata → ApiError
│  │  ├─ api_error.dart           ApiError(status, code, message, field, extra)
│  │  ├─ api_events.dart          StreamController<ApiEvent>: unauthenticated, blocked, offline, online, outdated
│  │  ├─ auth_api.dart            me, login, register, logout, changePassword, sessions, deletion
│  │  ├─ orders_api.dart, customers_api.dart, ratings_api.dart, cash_api.dart,
│  │  ├─ analytics_api.dart, settings_api.dart, dashboard_api.dart, mobile_api.dart
│  ├─ session/
│  │  ├─ token_store.dart         secure storage: refreshToken; bellekte accessToken
│  │  └─ session_controller.dart  status: loading|anonymous|blocked|ready, me, block, expired
│  ├─ models/                     Me, DeskOrder, CustomerRow, CustomerCard, RatingRow, Dashboard… (json_serializable/freezed)
│  ├─ constants/labels.dart       STATUS_LABELS, SERVICES, ROLE_LABELS, SKIP_REASON_LABELS…
│  ├─ validation/validate.dart    parsePhone, maskPhone, parseAmount, checkIban… (10-dogrulama-ve-bicim.md)
│  ├─ format/format.dart          money, displayPhone, formatDay, dayHeading…
│  ├─ theme/tokens.dart, app_theme.dart
│  ├─ ui/toast.dart, action_runner.dart, confirm_dialog.dart
│  └─ widgets/                    field.dart, phone_field.dart, password_field.dart, amount_field.dart,
│                                 list_state.dart, skeletons.dart, pager.dart, stepper_track.dart,
│                                 monogram.dart, more_menu.dart, app_sheet.dart, banners.dart
├─ router/app_router.dart         rotalar + redirect (guard'lar)
└─ features/
   ├─ shell/ops_shell.dart        yan menü / alt sekme / üst bar (finder) / destek bandı yok
   ├─ auth/login_page.dart, register_page.dart, blocked_page.dart, gate_layout.dart
   ├─ desk/desk_page.dart, archive_page.dart, widgets/order_card.dart, intake_form.dart, day_groups.dart
   ├─ customers/customers_page.dart, customer_drawer.dart
   ├─ ratings/ratings_page.dart, rating_preview_page.dart, widgets/star_picker.dart, reason_form.dart
   ├─ cash/cash_page.dart
   ├─ analytics/analytics_page.dart
   ├─ route_sheet/route_sheet_page.dart
   ├─ settings/settings_page.dart, team_section.dart, password_dialog.dart, devices_page.dart, delete_account_page.dart
   └─ password/password_page.dart
```

## 3. Oturum (bearer token)

Web çerez kullanır; **uygulama çerez kullanmaz.** Sunucu bunu zaten destekler (`ccs_server/docs/BUSINESS_RULES.md › Mobil oturum`).

### 3.1 Her istekte gönderilecek başlıklar

| Başlık | Değer | Not |
| --- | --- | --- |
| `X-Client` | `yunak-android/1.0.0` veya `yunak-ios/1.0.0` | Kalıp: `^yunak-(android\|ios)/\d{1,4}\.\d{1,4}\.\d{1,4}$`. Bozuksa `400 invalid_client`. Sürüm `package_info_plus` `version`'dan (build numarası değil). |
| `Authorization` | `Bearer <accessToken>` | Oturum gerektiren her istekte. Bearer varsa sunucu çereze hiç bakmaz. |
| `Accept` | `application/json` | |
| `Content-Type` | `application/json` | Gövdeli isteklerde |

### 3.2 Akış

```text
Açılış
  ├─ GET /api/mobile/config  → minVersion > mevcut sürüm ise "Güncelleme gerekli" ekranı (updateUrl)
  ├─ secure storage'da refreshToken yok → status = anonymous → /login
  └─ refreshToken var → POST /api/mobile/auth/refresh { refreshToken }
        ├─ 200 → yeni accessToken + refreshToken'ı KAYDET (eski artık geçmez) → GET /api/auth/me → ready
        ├─ 401 (unauthenticated | refresh_reused) → token sil → anonymous
        ├─ 403 tenant_* → blocked
        └─ ağ hatası → anonymous ama "bootOffline" işaretle; bağlantı gelince tekrar dene

Giriş
  POST /api/mobile/auth/login { phone, password, deviceName? }
     → { accessToken, accessExpiresAt, refreshToken, sessionExpiresAt, me }
     → token kaydet, status = ready (me cevapta gelir, ayrıca /me çağırmaya gerek yok)

Her istek
  accessExpiresAt'a < 60 sn kaldıysa önce refresh (proaktif)
  401 unauthenticated gelirse: TEK kez refresh dene → isteği tekrarla
      refresh de 401 → token sil → ApiEvent.unauthenticated → /login (state: from, expired: true)

Çıkış
  POST /api/mobile/auth/logout (bearer) → 204; hata olsa da tokenları sil → /login
```

- **Eşzamanlı refresh:** Aynı anda birden çok 401 gelirse tek bir refresh `Future`'ı paylaşılmalı (`Completer` ile kilit). Eski refresh token'ı 30 sn içinde ikinci kez gönderilirse sunucu "kaybolan cevap" sayar ve yeni çift verir; 30 sn sonra gönderilirse **çalıntı** sayar, oturumu kapatır (`401 refresh_reused`). Yani refresh cevabındaki yeni `refreshToken` her zaman hemen diske yazılmalı.
- `accessToken` yalnız bellekte tutulur; `refreshToken` `flutter_secure_storage` içinde.
- Oturum her refresh'te 30 gün uzar, girişten en geç 180 gün sonra biter (`sessionExpiresAt`).
- Kullanıcı başına en fazla 10 cihaz; 11. girişte en eski cihaz kapanır.
- **Genel admin (`super_admin`) uygulamadan giremez:** login `403 platform_admin_web_only` döner → giriş ekranında mesajı göster ("Platform paneli yalnız web'de açılır.").
- `426 client_outdated` → zorunlu güncelleme ekranı; `error.minVersion`, `error.updateUrl` (varsa "Güncelle" düğmesi mağazayı açar).

### 3.3 Oturum durumu (`SessionContext` karşılığı)

```dart
enum SessionStatus { loading, anonymous, blocked, ready }

class SessionState {
  final SessionStatus status;
  final Me? me;
  final BlockInfo? block;   // { code: tenant_pending|tenant_rejected|tenant_suspended|tenant_closing, message }
  final bool expired;       // 401 ile düştü → giriş ekranında "Oturumunuz sona erdi" yazar
}
```

| Olay | Davranış |
| --- | --- |
| `/me` 403 `tenant_*` | `blocked` → `BlockedPage` |
| `/me` ağ hatası | Mevcut durumu koru; ilk açılışsa `anonymous` + bağlantı gelince yeniden dene |
| Herhangi bir istek 401 (refresh de başarısız) ve durum `ready` | `anonymous`, `expired = true`, `/login`'e git, `from` = mevcut konum |
| Herhangi bir istek 403 `tenant_*` ve durum `ready` | `blocked` |
| `signIn` | login → `ready` |
| `signOut` | logout (hata yutulur) → `anonymous` |
| `refresh()` | `/me` tekrar okunur (Ayarlar kaydedilince çağrılır: firma adı/WhatsApp durumu değişir) |

`isManager(me)` = `me.user.role == 'admin' || me.user.role == 'super_admin'`.

### 3.4 Hareketsizlikte çıkış

Web'de 30 dk etkileşim yoksa oturum kapanır (`OpsLayout › useIdleSignOut`; ortak tezgâh bilgisayarı için). Flutter'da: kök widget'ı `Listener(onPointerDown: …)` ile sarın, her dokunuşta 30 dk'lık `Timer`'ı sıfırlayın; uygulama `paused` durumundan dönünce son etkileşimden 30 dk geçtiyse çıkış yapın. Süre dolunca `signOut()` → `/login` (`idle: true` → "Uzun süre işlem yapılmadığı için oturum kapatıldı.").

> Telefon kişisel cihazsa bu süre ayardan kapatılabilir yapılabilir; varsayılan web ile aynı kalsın.

## 4. HTTP katmanı (`api/http.js` karşılığı)

### 4.1 Hata modeli

Sunucu her hatayı aynı biçimde döner:

```json
{ "error": { "code": "invalid_phone", "message": "Geçerli bir cep telefonu girin.", "field": "phone", "retryAfterSeconds": 30, "suggested": "HK1043" } }
```

```dart
class ApiError implements Exception {
  final int status;          // 0 = ağ hatası
  final String code;         // yoksa "http_error"; ağda "network"
  final String message;      // yoksa "İşlem yapılamadı."
  final String? field;
  final Map<String, dynamic> extra; // error nesnesinin tamamı (suggested, reference, retryAfterSeconds, minVersion, updateUrl…)
}
```

Kurallar (`http.js`'ten):

- Ağ hatası / gövde okunurken kopma → `ApiError(0, "network", "Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.")` + `ApiEvent.offline`.
- Başarılı her cevapta, önceden offline idiyse `ApiEvent.online`.
- `204` → `null` döner.
- Gövde JSON değilse `payload = null`.
- `429` ve `retryAfterSeconds` yoksa `Retry-After` başlığından doldur.
- `401` ve yol şunlardan biri **değilse** `unauthenticated` olayı: `/api/auth/login`, `/api/auth/me`, `/api/auth/logout`, `/api/auth/password`, `/api/mobile/auth/*` (bu uçların 401'i "yanlış şifre" anlamına gelir).
- `403` ve `code` `tenant_` ile başlıyorsa `blocked` olayı.
- `426 client_outdated` → `outdated` olayı (zorunlu güncelleme ekranı).
- Yol parametreleri her zaman `Uri.encodeComponent` ile kodlanır (`seg()`).
- Query üretimi: `null`/boş değerler atlanır (`query()`), ör. `{tab: "open", q: "", page: 1}` → `?tab=open&page=1`.

### 4.2 Global olaylar

`ApiEvents` bir `StreamController.broadcast()`:

| Olay | Dinleyen |
| --- | --- |
| `unauthenticated` | SessionController → login'e yönlendir |
| `blocked(code, message)` | SessionController → BlockedPage |
| `offline` / `online` | NetworkBanner; SessionController (bootOffline ise `/me` yeniden) |
| `outdated(minVersion, updateUrl)` | Zorunlu güncelleme ekranı |

### 4.3 `useResource` karşılığı (liste/okuma)

Davranış (aynen korunmalı):

- Parametre (sekme, arama, sayfa…) değişince yeniden yükler. **Eski isteğin cevabı yenisinin üstüne yazılmaz** (her yüklemeye artan bir "ticket" verin, cevap geldiğinde ticket hâlâ sonuncusu mu bakın; Riverpod `family` + `autoDispose` bunu kendiliğinden sağlar).
- `reload()` → yükleniyor gösterir, eski hatayı siler.
- `reload(silent: true)` → arka planda yeniler, liste titremez; başarısızsa eski veri ekranda kalır ve `stale = true` olur.
- Durum: `{ data, error, loading, stale = error != null && data != null }`.

### 4.4 `useAction` karşılığı (mutasyon)

```dart
Future<ActionOutcome<T>> run<T>(Future<T> Function() action, {
  String? Function(T result)? success,   // başarı toast metni
  bool Function(ApiError e)? toastError, // false dönerse hata toast olmaz (alan altında gösterilecek)
});
```

- Bir işlem sürerken ikinci çağrı **hiç gönderilmez** (`skipped`). Düğmeler ayrıca `busy` iken pasif.
- Başarıda `success` metni yeşil toast; hatada sunucunun Türkçe `message`'ı kırmızı toast (aksi belirtilmedikçe).

### 4.5 Alan hataları (`useFieldErrors`)

- `errors: Map<String, String>`; kullanıcı alanı değiştirince o alanın hatası silinir.
- `fromApi(error)` → `fieldOfError(error, overrides)` ile alanı bulur (bkz. [02-api.md › Hata → alan](02-api.md#4-hata-kodu--form-alanı-eşlemesi)); alan bu formdaysa hatayı altına yazar ve `true` döner (toast gösterilmez).

## 5. Rotalar ve korumalar

| Yol | Sayfa | Koruma | Flutter'da |
| --- | --- | --- | --- |
| `/` | → `/ops` | | |
| `/login` | Giriş | Oturum açıksa → `/ops` | ✔ |
| `/register` | Firma başvurusu | Oturum açıksa → `/ops` | ✔ |
| `/ops` | İşler | oturum + firma | ✔ |
| `/ops/arsiv` | Arşiv | oturum + firma | ✔ |
| `/ops/musteriler` | Müşteriler | oturum + firma | ✔ |
| `/ops/degerlendirmeler` | Yorumlar | oturum + firma | ✔ |
| `/ops/puan-onizleme` | Puan ekranı önizleme | oturum + firma | ✔ |
| `/ops/servis` | Servis listesi | oturum + firma | ✔ |
| `/ops/sifre` | Şifremi değiştir | oturum | ✔ |
| `/ops/kasa` | Kasa | + yönetici | ✔ |
| `/ops/analiz` | Analiz | + yönetici | ✔ |
| `/ops/ayarlar` | Ayarlar + Ekip | + yönetici | ✔ |
| `/ops/super-admin` | İşletmeler | + super_admin | ✘ (web-only) |
| `/r/:token` | Müşteri puan sayfası | herkese açık | ✘ (web'de kalır) |
| — | Cihazlarım | oturum | **yeni** |
| — | Hesabı sil | oturum + firma sahibi (`me.user.isOwner`) | **yeni** |
| — | Güncelleme gerekli | | **yeni** |
| `*` | Sayfa bulunamadı | | ✔ |

`go_router` `redirect` mantığı (`Guards.jsx`):

```dart
redirect: (context, state) {
  final s = ref.read(sessionProvider);
  final path = state.matchedLocation;
  final isGate = path == '/login' || path == '/register';
  if (s.status == SessionStatus.loading) return '/splash';
  if (s.status == SessionStatus.blocked) return '/blocked';
  if (s.status != SessionStatus.ready) return isGate ? null : '/login?from=${Uri.encodeComponent(state.uri.toString())}';
  if (isGate) return '/ops';
  final me = s.me!;
  if (me.tenant == null) return '/login'; // uygulamada firmasız kullanıcı olmaz (super_admin giremez)
  const managerOnly = ['/ops/kasa', '/ops/analiz', '/ops/ayarlar'];
  if (managerOnly.contains(path) && !isManager(me)) return '/ops?notice=forbidden';
  return null;
}
```

- `refreshListenable` olarak session controller'ı bağlayın ki oturum düşünce yönlendirme kendiliğinden olsun.
- `notice=forbidden` → İşler ekranı açılınca kırmızı toast: **"Bu sayfaya yalnızca yöneticiler girebilir."** sonra parametreyi silin.
- Girişten sonra: `from` `/ops` ile başlıyorsa oraya, değilse `/ops`.

### Adres çubuğu parametreleri → sayfa durumu

Web'de liste filtreleri URL'dedir (`?tab=`, `?q=`, `?page=`, `?month=`, `?filter=`, `?period=`, `?range=`, `?fill=`, `?new=1`). Flutter'da bunları `GoRouterState.uri.queryParameters` ile okuyun ve değişiklikte `context.go(...)` ile yazın; böylece geri tuşu, derin link ve "Bildirimden açılış" aynı çalışır. Alternatif: her sayfanın kendi `StateProvider`'ı — ama `?fill=<customerId>` ve `?q=<fişno>` ile sayfalar arası geçişler (Analiz → İş kartı, Müşteri kartı → İşler) mutlaka korunmalı.

## 6. Global UI parçaları

| Parça | Davranış |
| --- | --- |
| **Toast** | Tek bildirim; iyi haber 3,8 sn, hata 6 sn görünür; × ile kapanır. Masaüstünde sağ üst, telefonda üstte tam genişlik. Flutter: `ScaffoldMessenger` + `SnackBarBehavior.floating` (üstte göstermek için `margin`), ya da `Overlay`. |
| **NetworkBanner** | Üstte kalıcı kırmızı şerit: **"Bağlantı yok."** + cihaz offline ise "İnternet bağlantınızı kontrol edin.", API ulaşılmıyorsa "Sunucuya ulaşılamıyor." + " Girdiğiniz bilgiler ekranda duruyor; bağlantı gelince yeniden gönderin." |
| **VersionNotice** | Web'de `/api/health.version` 5 dk'da bir izlenir, değişince "Yeni sürüm yayınlandı. [Yenile]". Uygulamada bunun yerine `/api/mobile/config` → `latestVersion > mevcut` ise kapatılabilir "Yeni sürüm var [Güncelle]" şeridi; `minVersion > mevcut` ise zorunlu ekran. |
| **ErrorBoundary** | Beklenmeyen hata: **"Bu ekran açılamadı"** / "Beklenmeyen bir hata oldu. Girdiğiniz veriler kaydedilmediyse yeniden yazmanız gerekebilir." / [Yeniden yükle] [Tekrar dene]. Flutter: `ErrorWidget.builder` + `FlutterError.onError` + sayfa içinde `try/catch`. |
| **Otomatik yenileme** | İşler 45 sn, Yorumlar 60 sn, Servis listesi 60 sn, Analiz 120 sn. Yalnız uygulama ön plandayken; uygulama ön plana gelince (son yenilemeden 5 sn geçtiyse) ve bağlantı gelince de yenile. `WidgetsBindingObserver.didChangeAppLifecycleState` + `Timer.periodic`. |
| **Kaydedilmemiş veri** | Web'de `beforeunload`. Flutter'da form kirliyken (`dirty`) `PopScope(canPop: !dirty)` + "Kaydedilmemiş değişiklikler var. Çıkılsın mı?" onayı. Sheet/drawer kapatılırken de. |
| **Sayfa düzeltme** | İstenen `page` toplam sayfadan büyükse sunucu son sayfayı döner (`data.page`); URL'deki `page` sunucunun döndüğüyle değiştirilir (1 ise parametre silinir). |
| **Başlık** | Web'de sekme başlığı "İşler · Firma adı · Yunak". Flutter'da AppBar başlığı yeterli. |
