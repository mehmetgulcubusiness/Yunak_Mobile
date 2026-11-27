# 04 — Uygulama kabuğu ve kimlik ekranları

## 1. OpsShell (`layouts/OpsLayout.jsx`)

Bütün `/ops/*` sayfaları bu kabuğun içindedir (`go_router` `ShellRoute`). Kabuk şunları sağlar:

| Parametre (React prop) | Anlamı | Flutter |
| --- | --- | --- |
| `section` | Aktif menü öğesi: `desk`, `archive`, `customers`, `ratings`, `route`, `cash`, `analytics`, `settings`, `password` | Rota adından türetin |
| `title`, `subtitle` | Sayfa başlığı ve altı (İşler sayfası başlık çizmez, selam gösterir) | AppBar / sayfa başı |
| `actions` | Başlığın sağındaki düğmeler (Kasa: Excel, Yazdır; Analiz: dönem seçici) | AppBar `actions` |
| `search` | Üst bar araması: `{ placeholder, label }` | `Finder` widget'ı |
| `onNew` | "+ Yeni Fiş Oluştur" ve alt çubuktaki + | İşler'de sheet açar; diğer sayfalarda `/ops?new=1` |
| `lead` | Üst barın solunda (İşler'de selam) | |

### 1.1 Gösterge verisi (Dashboard)

Kabuk açılınca `GET /api/dashboard` bir kez yüklenir; `dashboardProvider` olarak bütün sayfalara açıktır (`useDashboard()`). Sayfalar bir işlem yaptıktan sonra `reloadDashboard()` çağırır. Hata olursa son bilinen değer kalır.

Kabuktaki kullanımı:
- `crises = dashboard.openCrises ?? me.openCrises ?? 0` → Yorumlar rozetleri.
- `overdue = dashboard.overdue` → Analiz menüsünde rozet ("geciken iş").

### 1.2 Yan menü (masaüstü sabit, telefonda çekmece)

Üstte marka: altın 34×34 logo kutusu (`mark` ikonu, `goldInk`) + **firma adı** (firma yoksa "Yunak Platform"). Dokununca `/ops`.

**Menü (firma kullanıcısı):**

| Öğe | Rota | İkon | Rozet |
| --- | --- | --- | --- |
| İşler | `/ops` | desk | |
| Arşiv | `/ops/arsiv` | archive | |
| Müşteriler | `/ops/musteriler` | user | |
| Yorumlar | `/ops/degerlendirmeler` | star | `crises` (bekleyen şikâyet) |
| Servis listesi | `/ops/servis` | truck | |

**Yalnız yönetici:**

| Öğe | Rota | İkon | Rozet |
| --- | --- | --- | --- |
| Kasa | `/ops/kasa` | till | |
| Analiz | `/ops/analiz` | chart | `overdue` (geciken iş) |
| Ayarlar | `/ops/ayarlar` | gear | |

(`super_admin` için "İşletmeler" web-only; Flutter'da yok.)

Seçili öğe: beyazımsı yazı + koyu ikinci zemin (`side2`). Diğerleri `sideInk`.

**Alt kısım:**

1. **WhatsApp durumu** (tek cümle):
   - `tenant.whatsappBound == false` → gri led, **"WhatsApp bağlı değil"** / "Bağlamak için dokunun"
   - bağlı ve `queue.failed + queue.uncertain > 0` → kırmızı led, **"Mesajlarda sorun var"** / "`N` mesaj ulaşmadı"
   - bağlı ve sorun yok → yeşil led, **"WhatsApp bağlı"** / "`queue.sent` mesaj iletildi"
   - Yönetici ise dokununca `/ops/ayarlar`; personelde dokunulmaz.
2. **Kullanıcı:** Monogram + ad + rol etiketi (`Platform Yöneticisi` / `Yönetici` / `Personel`).
3. Bağlantılar: **"Şifremi değiştir"** (`/ops/sifre`), **"Çıkış"**. Flutter'da buraya **"Cihazlarım"** ve (sahipse) Ayarlar içinde **"Hesabı sil"** eklenir.

### 1.3 Üst komut çubuğu

- ☰ menü düğmesi (≤900; şikâyet varsa kırmızı nokta).
- `lead` (masaüstünde İşler selamı).
- **Finder** (arama) — bkz. aşağı.
- **"+ Yeni Fiş Oluştur"** (masaüstü; telefonda gizli, alt çubuktaki + kullanılır). "+" altın.

### 1.4 Finder (arama kutusu)

- Değer URL'deki `q` parametresidir. Yazmayı bırakınca **350 ms** sonra uygulanır; Enter'da hemen.
- `trim()` edilir, en fazla **80** karakter; uygulanınca `page` parametresi silinir.
- Değer boşsa `q` silinir. Doluysa yanında **×** ("Aramayı temizle").
- URL'deki `q` dışarıdan değişirse (geri tuşu) kutu eşitlenir.
- Klavye `/` kısayolu (masaüstü) — Flutter'da gerekmez (donanım klavyeli tablette `Shortcuts` ile eklenebilir).
- `TextInputAction.search`, otomatik düzeltme kapalı.

Sayfa placeholder'ları:

| Sayfa | placeholder |
| --- | --- |
| İşler | Ad, telefon veya fiş no ara |
| Arşiv | Arşivde ad, telefon veya fiş no ara |
| Müşteriler | Ad, telefon veya adres ara |
| Yorumlar | Ad, telefon, fiş no veya şikâyet ara |

### 1.5 Alt sekme çubuğu (≤900, yalnız firma varken)

`İşler` · `Müşteriler` · **`+`** · `Yorumlar` (+ `crises` rozeti) · `Menü` (çekmeceyi açar).
`+`: sayfanın `onNew`'u varsa onu çağırır, yoksa `/ops?new=1`.

### 1.6 Destek modu bandı

Web'de genel admin başka firmadayken üstte "Destek modu: X · HH:MM'de kendiliğinden kapanır [Çık]". **Uygulamada genel admin giremediği için yazılmaz.**

### 1.7 Hareketsizlik

30 dk etkileşim yoksa çıkış → `/login` ("Uzun süre işlem yapılmadığı için oturum kapatıldı."). Bkz. [01-mimari.md §3.4](01-mimari.md#34-hareketsizlikte-çıkış).

---

## 2. GateLayout (giriş/kayıt ortak çerçevesi — `pages/auth/GateLayout.jsx`)

**Geniş ekran (>900):** iki sütun.

Sol "hikâye" paneli (koyu):
- Marka: logo + "Yunak".
- Ürün önizlemesi (sahte pencere, yalnız süs): 3 KPI ("Açık iş 8", "Yıkamada 4", "Bugünkü ciro 5.600 ₺" — altın nokta), 2 iş satırı:
  - Ayşe Yılmaz · Halı Yıkama · #HK1001 · adım 1/3 · 3.250 ₺
  - Mustafa Çelik · Koltuk Yıkama · #HK1002 · adım 2/3 · 2.100 ₺
  - Altında "✓ Müşteriye WhatsApp'tan haber gitti" balonu ve "★★★★★ Yeni yorum" balonu.
- Başlık: **"Halı yıkama işinizi tek ekrandan yönetin."**
- Maddeler (✓): "Fişi saniyeler içinde açın" · "Müşteriye WhatsApp'tan otomatik haber gitsin" · "Şikâyeti ilk siz duyun, kasanızı tek ekranda görün"
- Alt not: "Halı, koltuk, yorgan ve perde yıkama için · WhatsApp ile çalışır"

Sağ panel (beyaz kart): küçük marka, `title` (h1), `lead`, kırmızı `error` kutusu, yeşil `notice` kutusu, form, `footer` bağlantısı.

**Telefon:** yalnız sağ panel (önizleme gösterilmez). Flutter'da `LayoutBuilder` + `SingleChildScrollView`; klavye açılınca form kaydırılabilir olmalı.

---

## 3. Giriş — `/login` (`pages/auth/LoginPage.jsx`)

| Öğe | Metin / davranış |
| --- | --- |
| Başlık | **Hoş geldiniz** |
| Alt metin | Telefon numaranız ve şifrenizle giriş yapın. |
| Alan 1 | `PhoneField` — etiket **"Cep Telefonu"**, maske `0532 111 00 31`, `autofillHints: telephoneNumber/username` |
| Alan 2 | `PasswordField` — etiket **"Şifre"**, göster/gizle, `autofillHints: password` |
| Düğme | **"Giriş yap"** · gönderirken "Giriş yapılıyor…" · beklemede "Bekleyin (N sn)" |
| Alt bağlantı | "Hesabınız yok mu? **İşletmenizi kaydedin**" → `/register` |

**Bilgi kutusu (`notice`)** — gelinen duruma göre:

| Durum (`extra`/query) | Metin |
| --- | --- |
| `registered` | Başvurunuz alındı. Onaylandığında bu ekrandan giriş yapabilirsiniz. |
| `expired` | Oturumunuz sona erdi. Kaldığınız sayfaya dönmek için yeniden giriş yapın. |
| `idle` | Uzun süre işlem yapılmadığı için oturum kapatıldı. |
| `passwordChanged` | Şifreniz değişti. Yeni şifrenizle giriş yapın. |

**Gönderim:**
1. İstemci doğrulaması: `checkPhone(phone)`, `checkPassword(password)` (8–72 UTF-8 bayt). Hatalar alan altına.
2. `POST /api/mobile/auth/login { phone: <ham giriş>, password, deviceName }` (web ham telefonu gönderir; sunucu normalleştirir).
3. Başarı → token kaydet → `from` `/ops` ile başlıyorsa oraya, değilse `/ops` (`replace`).
4. Hata:
   - `429` → `retryAfterSeconds` (yoksa 60) saniyelik geri sayım; hata: "Çok fazla deneme yapıldı. N saniye sonra yeniden deneyin."; düğme pasif.
   - `invalid_credentials` → formun üstünde mesaj.
   - Alan eşlenebiliyorsa alan altında; değilse formun üstünde.
   - `403 tenant_*` → (sunucu mobil login'de 401 de dönebilir) BlockedPage.
   - `403 platform_admin_web_only` → "Platform paneli yalnız web'de açılır." (sunucu mesajını gösterin).
   - `426` → güncelleme ekranı.

> Flutter ek: "Silme talebini geri al" bağlantısı (firma `closing` ise) → `POST /api/account/deletion/cancel { phone, password }` (bkz. 11-yol-haritasi).

---

## 4. Kayıt — `/register` (`pages/auth/RegisterPage.jsx`)

| Öğe | Metin |
| --- | --- |
| Başlık | **İşletmenizi kaydedin** |
| Alt metin | Başvurunuzu inceleyip kısa sürede hesabınızı açıyoruz. |
| Alanlar (`NewAccountFields`) | **İşletme / Marka Adı** (≤120) · **Yetkili Adı Soyadı** (≤120) · **Cep Telefonu** · **Şifre** (güç göstergesi, ipucu "En az 8 karakter; en az bir harf ve bir rakam.") · **Şifre (tekrar)** |
| Düğme | **"Başvuruyu Gönder"** / "Gönderiliyor…" |
| Alt bağlantı | "Hesabınız var mı? **Giriş yapın**" |

Doğrulama (`checkNewAccount`): `checkBrandName(business)`, `checkPersonName(name)`, `checkPhone(phone)`, `checkNewPassword(password, phone)`, `checkPasswordRepeat(password, repeat)`.

Gönderim: `POST /api/auth/register { business, name, phone (E.164), password }` → formu sıfırla → `/login` (`registered: true`). Hata alana eşlenemezse üstte.

Kaydedilmemiş veri koruması: herhangi bir alan doluysa ve gönderilmiyorsa geri tuşunda onay.

---

## 5. Bloklu firma — `BlockedPage`

Firma `pending` / `rejected` / `suspended` / `closing` olduğunda (`403 tenant_*`).

| code | Başlık |
| --- | --- |
| `tenant_pending` | Başvurunuz onay bekliyor |
| `tenant_rejected` | Başvurunuz onaylanmadı |
| `tenant_suspended` | İşletme hesabınız askıya alınmıştır. |
| diğer | Hesap kapalı |

Gövde: sunucu mesajı, yoksa "Lütfen platform yönetimiyle iletişime geçin." Tek düğme: **"Giriş ekranına dön"** → `signOut()` → `/login`.

`tenant_closing` için Flutter'da ek: "Silme talebini geri al" düğmesi (sahip, telefon + şifre).

---

## 6. Sayfa bulunamadı — `NotFoundPage`

GateLayout içinde: başlık **"Sayfa bulunamadı"**, alt metin "Aradığınız adres bu uygulamada yok.", bağlantı **"Ana sayfaya dön"** → `/ops`. Flutter'da `GoRouter.errorBuilder`.

---

## 7. Şifremi değiştir — `/ops/sifre` (`pages/ops/PasswordPage.jsx`)

Kabuk başlığı: **"Şifremi değiştir"**. Dar kart içinde:

- İpucu: "Yeni şifre en az 8 karakter olmalı, en az bir harf ve bir rakam içermeli ve telefon numaranızla aynı olmamalı."
- **Mevcut şifre** · **Yeni şifre** (güç göstergesi) · **Yeni şifre (tekrar)**
- Düğme: **"Şifreyi Değiştir"** / "Kaydediliyor…"

Doğrulama:
- Mevcut boş → "Mevcut şifrenizi girin."
- `checkNewPassword(new, me.user.phone)`; aynıysa → "Yeni şifre eskisiyle aynı olamaz."
- `checkPasswordRepeat`.

Gönderim: `POST /api/auth/password { currentPassword, newPassword }`.
- Başarı toast: "Şifreniz değiştirildi. Diğer cihazlardaki oturumlar kapanır." Form sıfırlanır.
  - ⚠️ Sunucu şifre değişince diğer oturumları kapatır. Bu cihazın oturumu açık kalıyorsa devam; sonraki istek 401 dönerse login'e `passwordChanged: true` ile gidin.
- `404` → mevcut şifre alanına "Sunucu şifre değiştirmeyi henüz desteklemiyor."
- Alan eşlemesi: `invalid_credentials`/`wrong_password` → `currentPassword`, `password_unchanged` → `newPassword`.

---

## 8. 🆕 Cihazlarım (Flutter'a özel)

`GET /api/auth/sessions` → liste: platform ikonu (web/android/ios), `deviceName` (yoksa "Tarayıcı"/"Telefon"), `clientVersion`, "Son görülme: `formatStamp(lastSeenAt)`", `current` ise "Bu cihaz" rozeti.
Her satırda (current hariç) **"Oturumu kapat"** → onay → `DELETE /api/auth/sessions/:id` → listeyi yenile. Altta **"Tüm cihazlardan çık"** → `POST /api/auth/logout-all` → login.

## 9. 🆕 Güncelleme gerekli

`426 client_outdated` veya açılışta `minVersion > mevcut`:
Başlık "Uygulamanın yeni sürümünü yükleyin.", alt "Devam etmek için güncelleyin.", düğme **"Güncelle"** (`updateUrl` → `url_launcher`). Geri dönülemez ekran.
