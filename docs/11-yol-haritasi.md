# 11 — Yol haritası, farklar ve kontrol listesi

## 1. Uygulama sırası (önerilen)

| Adım | İş | Bitti sayılması için |
| --- | --- | --- |
| 1 | Proje iskeleti, tema (`03`), Inter fontu, ikonlar (SVG), `tr_TR` yerelleştirme | Boş kabuk açılıyor, renkler/fontlar doğru |
| 2 | `validate.dart`, `format.dart`, `labels.dart` + ortak test vakaları | `flutter test` yeşil; web testleriyle aynı sonuçlar |
| 3 | `ApiClient` (X-Client, Bearer, refresh kilidi, hata modeli, olaylar), `TokenStore` | Login/refresh/logout çalışıyor; 401'de bir kez refresh |
| 4 | `SessionController`, `go_router` + redirect, Splash, Login, Register, Blocked, NotFound, Güncelleme gerekli | Oturum düşünce login'e `expired` ile dönüyor |
| 5 | OpsShell (yan menü / çekmece / alt sekme / Finder / dashboard provider / hareketsizlik) | Rozetler ve WhatsApp durumu doğru |
| 6 | Ortak widget'lar (`09`) | Field, Phone/Password/AmountField, ConfirmDialog, ListState, Pager, Stepper |
| 7 | **İşler** + OrderCard + IntakeForm + DayGroups | Geri al (5 sn), duplicate_today, reference_taken, otomatik yenileme |
| 8 | Arşiv, Müşteriler + CustomerDrawer | KVKK silme (ad yazarak onay), not, opt-in/out |
| 9 | Yorumlar + Puan önizleme | Filtreler, Çözüldü, özet rayı |
| 10 | Servis listesi (rota linki), Şifremi değiştir | |
| 11 | Yönetici: Kasa (grafik, Excel paylaş, PDF), Analiz (6 tile, grafikler, ısı haritası), Ayarlar + Ekip | |
| 12 | 🆕 Cihazlarım, Hesabı sil, silme talebini geri al | Mağaza incelemesi için hazır |
| 13 | Yazdırma (fiş PDF), uygulama ikonu/splash, mağaza yayını | |

## 2. Web'den bilinçli farklar

| Konu | Web | Flutter |
| --- | --- | --- |
| Oturum | HttpOnly çerez | Bearer + refresh token (secure storage) |
| Giriş ucu | `/api/auth/login` | `/api/mobile/auth/login` (+ `deviceName`) |
| Çıkış ucu | `/api/auth/logout` | `/api/mobile/auth/logout` |
| Genel admin | İşletmeler paneli + destek modu | Yok (`platform_admin_web_only`) |
| Müşteri puan sayfası `/r/:token` | React sayfası | Yok; web'de kalır |
| Tanıtım sitesi (`/`, `/hakkimizda`, `/iletisim`) | Statik HTML | Yok |
| Sürüm bildirimi | `/api/health.version` | `/api/mobile/config` (`minVersion`, `latestVersion`, `updateUrl`) + `426` |
| Yazdırma | `window.print()` | `printing` + `pdf` |
| Excel | `<a download>` | indir + paylaş |
| Kaydedilmemiş veri | `beforeunload` | `PopScope` + onay |
| Klavye kısayolları (`/` arama, ok tuşları, Esc) | var | gerek yok (fiziksel klavyede isteğe bağlı) |
| Odak kapanı (`useFocusTrap`) | var | Flutter modal'ları zaten sağlar |
| Liste yenileme | 45/60/120 sn + sekme odağı | aynı + **aşağı çekerek yenile** |
| Dış linkler | `target="_blank"` | `url_launcher` `externalApplication` (`tel:`, `wa.me`, Maps) |
| Hesap silme, Cihazlarım | yok | **var** (mağaza zorunluluğu / güvenlik) |

## 3. Sunucu tarafında gereken değişiklikler

1. **CSRF origin koruması ve oturumsuz POST'lar.** `csrfUnlessTokenOnly` yalnız *bearer taşıyan* ve `/api/mobile/*` isteklerini muaf tutar. Uygulamanın oturumsuz yaptığı şu POST'lar üretimde `403 origin_refused` alır (Origin/Referer yok):
   - `POST /api/auth/register`
   - `POST /api/account/deletion/cancel`
   
   Önerilen çözüm (sunucu): bu iki ucun mobil eşlerini `/api/mobile/auth/register` ve `/api/mobile/account/deletion/cancel` olarak eklemek (çerez okumadıkları için CSRF'ye gerek yok). Geçici çözüm: uygulama bu isteklerde `Origin: <PUBLIC_BASE_URL>` başlığı gönderir (native istemci için güvenlik açığı yaratmaz ama sözleşme dışıdır).
2. **`Me.tenant.setup`** (`googleReview`, `iban`) client'ta kullanılıyor ama `openapi.yaml › Me` şemasında yok — şemaya eklenmeli (mobil sözleşme kuralı: alan eklenir, kaldırılmaz).
3. **`OpenOrderResult.reference`** client'ta okunuyor ("X doluydu, Y verildi"), şemada yok — eklenmeli.
4. `MOBILE_MIN_VERSION`, `MOBILE_LATEST_VERSION`, `MOBILE_UPDATE_URL` ortam değişkenleri yayın öncesi ayarlanmalı.
5. Web build'i (`ccs_client/dist`) sunucuda kalmalı: `/r/:token` puan sayfası müşteriler için oradan çalışır.

## 4. Davranış kontrol listesi (kabul testleri)

Oturum
- [ ] İlk açılışta refresh token yoksa giriş ekranı; varsa refresh + `/me` ile doğrudan İşler.
- [ ] Access token süresi dolunca kullanıcı fark etmeden yenileniyor; aynı anda 3 istek → tek refresh.
- [ ] Başka cihazdan "oturumu kapat" → bu cihaz bir sonraki istekte giriş ekranına "Oturumunuz sona erdi" ile düşüyor.
- [ ] 30 dk hareketsizlik → çıkış, "Uzun süre işlem yapılmadığı…".
- [ ] Art arda hatalı girişte 429 → düğmede geri sayım (`retryAfterSeconds`).
- [ ] Firma askıya alınınca açık uygulama BlockedPage gösteriyor.
- [ ] Eski sürüm (`minVersion` altı) → zorunlu güncelleme ekranı.

İşler
- [ ] Sekme sayaçları dashboard'dan; personelde ciro kartı yok.
- [ ] "Yıkamaya Al →" → 5 sn "Geri al"; geri alınca istek gitmiyor; süre dolunca toast "Yıkamaya alındı: #REF".
- [ ] Geri al süresi içinde sekme değiştirilince istek yine gidiyor.
- [ ] Kaydırınca kart yeniden oluşturulsa da bekleyen ilerletme kaybolmuyor/erken gitmiyor.
- [ ] Başka cihaz durumu değiştirdiyse `illegal_transition` → toast + liste yenileniyor.
- [ ] Biten işte personel "Tutar ve Not Düzenle" görmüyor; yönetici görüyor.
- [ ] "Teslimatı Geçersiz Say" yalnız yöneticide.
- [ ] 45 sn'de bir sessiz yenileme; ön plana dönünce yenileme.

Yeni fiş
- [ ] Kayıtlı telefon yazıp alandan çıkınca "Kayıtlı müşteri: Ad" ve ad/adres doluyor.
- [ ] Mesajları kapalı müşteride sarı uyarı.
- [ ] m² × fiyat → toplam kendiliğinden ("12,5" × "80" → "1.000,00").
- [ ] "1.25" → "Kuruş için virgül kullanın: 1,25".
- [ ] Toplam > 1.000.000 → hata.
- [ ] Fiş no'ya "işçi" yazınca "ISCI" oluyor.
- [ ] Aynı gün aynı müşteriye ikinci fiş → "Bu müşteriye bugün fiş açıldı" onayı.
- [ ] Dolu fiş no → "X numarasını kullan".
- [ ] Başarıdan sonra hizmet seçimi korunuyor, diğer alanlar boş.
- [ ] Sheet kapatılıp açılınca yazılanlar duruyor.

Müşteri / Yorumlar / Yönetici
- [ ] KVKK silme müşterinin adı yazılmadan açılmıyor (büyük/küçük harf ve "i/İ" fark etmeden).
- [ ] Ayarlarda IBAN yazarken 4'lü gruplanıyor, mod-97 hatası yakalanıyor.
- [ ] Ayarlar kaydedilince kabuktaki firma adı ve WhatsApp durumu güncelleniyor.
- [ ] Kasa Excel dosyası paylaş menüsüyle açılıyor.
- [ ] Servis listesinde 3 durak seçip "Haritada rota aç" → Google Maps çok duraklı rota.
- [ ] Analiz "Geciken işler"e İşler'deki todo'dan kaydırarak gidiliyor.

Biçim
- [ ] Bütün saatler cihaz saat diliminden bağımsız İstanbul saati.
- [ ] Para "1.250 ₺" / "1.250,50 ₺"; telefon "0532 111 00 31".
- [ ] Bozuk/boş tarih ekranı çökertmiyor (boş metin).

## 5. Önerilen paketler (`pubspec.yaml`)

```yaml
dependencies:
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  intl: ^0.19.0
  url_launcher: ^6.2.0
  package_info_plus: ^8.0.0
  device_info_plus: ^10.0.0
  connectivity_plus: ^6.0.0
  fl_chart: ^0.68.0
  flutter_svg: ^2.0.0
  pdf: ^3.10.0
  printing: ^5.12.0
  path_provider: ^2.1.0
  share_plus: ^9.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  flutter_lints: ^4.0.0
```

(Sürümleri projeyi açtığınız günün güncel kararlı sürümlerine göre güncelleyin.)

## 6. Ortam

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080      # Android emülatör → yerel ccs_server
flutter run --dart-define=API_BASE_URL=https://yunak.com.tr       # yayın
```

- Geliştirme sunucusu `NODE_ENV=production` olmadan çalışırken iş kartlarında "Müşteri Yıldız Ekranını Aç (Test)" linki görünür (`previewToken`); yayında görünmemeli.
- Android'de düz HTTP için yalnız debug'da `usesCleartextTraffic` açın.
- **Canlı veritabanına karşı test yapmayın** (web README ile aynı kural).
