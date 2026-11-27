# Yunak — mobil uygulama (Flutter)

`ccs_client` web panelinin Android/iOS karşılığı. Tasarım ve sözleşme belgeleri: [`docs/`](docs/README.md).

## Çalıştırma

```bash
flutter pub get
# Canlı sunucuya (varsayılan):
flutter run
# Android emülatöründen yerel sunucuya:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

| Değişken | Varsayılan | Anlamı |
| --- | --- | --- |
| `API_BASE_URL` | `https://yunakhaliyikama.com.tr` | `ccs_server` kökü |
| `WEB_BASE_URL` | `API_BASE_URL` | Puan sayfası (`/r/:token`) ve `Origin` başlığı için web kökü |

Geliştirme derlemesinde yerel `http` adresine izin verilir (`android/app/src/debug/AndroidManifest.xml`); yayın sürümü yalnız `https` kullanmalı.

## Sunucu gereksinimi

Uygulama açılışta `GET /api/mobile/config`'e bakar. Sunucuda mobil uçlar **yoksa** web paneli gibi çerezli oturumla
(`/api/auth/login`, `Origin: <site>`) çalışır; bu modda Cihazlarım ve Hesabı sil gizlenir. Mobil uçlar varsa token kullanılır.

Uygulama `/api/mobile/*` (token ile giriş/yenileme/çıkış, sürüm kontrolü), `/api/auth/sessions` (Cihazlarım) ve
`/api/account/deletion` (Hesabı sil) uçlarını kullanır. Bu uçlar `ccs_server`'ın **`faz-2-mobil-tasarim`** dalındadır;
`dev`/`main` dallarında yoktur. Sunucuda `MOBILE_MIN_VERSION`, `MOBILE_LATEST_VERSION`, `MOBILE_UPDATE_URL` ayarlanmalıdır.

## Yapı

```text
lib/
  core/      config, theme (tokenlar), api (istemci, uçlar, token deposu, olaylar), models,
             session (oturum durumu), validation + format (web ve sunucuyla aynı kurallar), constants (etiketler)
  ui/        shell (yan menü, alt sekmeler, arama, hareketsizlik), auth, desk (İşler, Arşiv, iş kartı, yeni fiş),
             customers, ratings, route, manager (Kasa, Analiz, Ayarlar, Ekip), account (şifre, cihazlar, hesap silme),
             print (fiş PDF), widgets (ortak parçalar)
  app/       router (go_router + oturum yönlendirmesi)
assets/      icons (web'deki Icon.jsx'ten üretilmiş SVG'ler), fonts (Inter, OFL lisansı)
test/        contract_cases.json (sunucu ve web ile ortak doğrulama vakaları) + birim testleri
```

## Kontrol

```bash
flutter analyze
flutter test
```
