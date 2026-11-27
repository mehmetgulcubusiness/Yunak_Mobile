# Yunak — React client → Flutter dönüşüm belgesi

Bu klasör `ccs_client` (Vite + React SPA) uygulamasını **aynı ekranlar, aynı davranış ve aynı API** ile Flutter'a taşımak için yazıldı. Kaynak kod incelenerek çıkarıldı (2026-11-27). Bir ekranı yazarken önce ilgili sayfa belgesini, sonra ortak bileşen ve doğrulama belgelerini okuyun.

| Dosya | İçerik |
| --- | --- |
| [01-mimari.md](01-mimari.md) | Teknoloji eşlemesi, klasör yapısı, oturum (bearer token), HTTP katmanı, rota korumaları, global olaylar |
| [02-api.md](02-api.md) | Bütün API uçları: istek, cevap alanları, hata kodları, alan eşlemesi |
| [03-tasarim.md](03-tasarim.md) | Renkler, tipografi, boşluklar, kırılım noktaları, ikonlar, `ThemeData` |
| [04-kabuk-ve-auth.md](04-kabuk-ve-auth.md) | Uygulama kabuğu (yan menü / alt sekme), Giriş, Kayıt, Bloklu firma, 404, Şifre değiştir |
| [05-isler-arsiv.md](05-isler-arsiv.md) | İşler (Tezgâh), Arşiv, İş kartı (OrderCard), Yeni fiş formu (IntakeForm) |
| [06-musteriler-yorumlar.md](06-musteriler-yorumlar.md) | Müşteriler, Müşteri kartı (drawer), Yorumlar, Puan ekranı önizleme |
| [07-yonetici-sayfalari.md](07-yonetici-sayfalari.md) | Kasa, Analiz, Servis listesi, Ayarlar + Ekip |
| [08-platform-ve-puan-sayfasi.md](08-platform-ve-puan-sayfasi.md) | Genel admin (İşletmeler) ve müşteri puan sayfası `/r/:token` — neden web'de kalır |
| [09-ortak-bilesenler.md](09-ortak-bilesenler.md) | Field, PhoneField, PasswordField, AmountField, ConfirmDialog, Sheet, MoreMenu, Stepper, Pager, ListState, Toast… |
| [10-dogrulama-ve-bicim.md](10-dogrulama-ve-bicim.md) | `validate.js` ve `format.js`'in Dart karşılıkları (birebir kurallar), sabit metinler (`labels.js`) |
| [11-yol-haritasi.md](11-yol-haritasi.md) | Uygulama sırası, web'den farklı olan noktalar, sunucu tarafında gereken küçük değişiklikler, test listesi |

## Kısa özet

- **Uygulama ne yapıyor?** Halı / koltuk / yorgan / perde yıkama işletmeleri için tezgâh paneli. Fiş açılır, iş durumları ilerletilir (Teslim alındı → Yıkamada → Teslim edildi; koltukta Randevulu → İşlemde → Bitti), müşteriye WhatsApp'tan otomatik mesaj gider, teslimden sonra müşteriden yıldız puanı istenir. Yönetici kasayı, analizi ve ayarları görür.
- **Roller:** `staff` (Personel), `admin` (Yönetici), `super_admin` (Platform yöneticisi). Yönetici = `admin` **veya** `super_admin`.
- **Dil:** Yalnız Türkçe. Bütün metinler belgelerde birebir yazılıdır; aynen kullanın.
- **Saat dilimi:** Bütün tarih/saat gösterimleri **Europe/Istanbul**. Cihaz saat diliminden bağımsız olmalı.
- **Para:** `tr-TR` biçimi, `1.250,50 ₺`. Tutar girişinde virgül ondalık, nokta yalnız binlik.

## Flutter'da web'den farklı olacak 5 kritik nokta

1. **Oturum çerezle değil bearer token ile.** Sunucuda hazır: `POST /api/mobile/auth/login` → `accessToken` (15 dk) + `refreshToken`. Her istekte `Authorization: Bearer …` ve `X-Client: yunak-android/1.0.0` başlığı. Ayrıntı: [01-mimari.md › Oturum](01-mimari.md#3-oturum-bearer-token).
2. **Genel admin uygulamaya giremez** (`403 platform_admin_web_only`). İşletmeler paneli ve destek modu yalnız web'dedir; Flutter'da yazılmaz.
3. **Müşteri puan sayfası (`/r/:token`) web'de kalır.** Müşteri linki WhatsApp'tan tarayıcıda açar; uygulamaya gerek yoktur. Uygulamada yalnız "önizleme" ekranı olur.
4. **Uygulama mağazası kuralları:** Hesap silme ekranı (`POST /api/account/deletion`, yalnız firma sahibi) ve "Cihazlarım" (`/api/auth/sessions`) web client'ta yok ama Flutter'da **zorunlu/önerilir**.
5. **Yazdırma ve Excel:** `window.print()` yerine `printing` paketi (PDF/termal fiş), Excel indirme yerine dosyayı indirip paylaş menüsü.

## Kaynak eşleme tablosu

| React (ccs_client/src) | Flutter (önerilen `lib/`) |
| --- | --- |
| `api/http.js` | `core/api/api_client.dart` (Dio + interceptor) |
| `api/endpoints.js` | `core/api/*_api.dart` (her grup bir sınıf) |
| `context/SessionContext.jsx` | `core/session/session_controller.dart` (Riverpod `Notifier`) |
| `context/ToastContext.jsx` | `core/ui/toast.dart` (ScaffoldMessenger / overlay) |
| `hooks/useResource.js` | `AsyncNotifier` / `FutureProvider.autoDispose.family` + sessiz yenileme |
| `hooks/useAction.js` | `core/ui/action_runner.dart` (busy kilidi + toast) |
| `hooks/useFieldErrors.js` | `core/forms/field_errors.dart` |
| `hooks/usePageEffects.js` | `AutoRefresh` widget'ı, `PopScope` (kaydedilmemiş veri), sayfa düzeltme |
| `hooks/useFocusTrap.js` | Gerek yok (Flutter dialog/bottom sheet zaten modal) |
| `layouts/OpsLayout.jsx` | `features/shell/ops_shell.dart` (`ShellRoute`) |
| `layouts/Guards.jsx` | `go_router` `redirect` |
| `components/*` | `core/widgets/*` ve `features/<sayfa>/widgets/*` |
| `pages/*` | `features/<sayfa>/<sayfa>_page.dart` |
| `constants/labels.js` | `core/constants/labels.dart` |
| `utils/validate.js` | `core/validation/validate.dart` |
| `utils/format.js` | `core/format/format.dart` |
| `utils/contract-cases.json` | `test/contract_cases.json` (aynı dosya, Dart testinde okunur) |
| `styles/base.css` | `core/theme/tokens.dart` + `app_theme.dart` |

Sunucunun kendi belgeleri (asıl kaynak): `ccs_server/docs/openapi.yaml`, `ERROR_CODES.md`, `BUSINESS_RULES.md`.
