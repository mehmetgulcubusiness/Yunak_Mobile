# 08 — Platform paneli ve müşteri puan sayfası

Bu iki ekran **Flutter uygulamasına taşınmaz**. Nedenleri ve referans için içerikleri aşağıdadır.

## 1. İşletmeler (genel admin) — `/ops/super-admin` (`pages/ops/PlatformPage.jsx`)

**Neden web-only:** Sunucu `super_admin`'in uygulamadan girişini `403 platform_admin_web_only` ile reddeder; destek modu (başka firmaya geçiş, çerez yeniden imzalama) yalnız web oturumunda çalışır. Uygulamada bu rol için giriş ekranında sunucu mesajını gösterin.

İleride gerekirse (sunucu izin verirse) içerik:

- Sekmeler (`status`): **Onay Bekleyen** (`pending`, varsayılan) · **Aktif** · **Askıda** · **Reddedilen** · **Tümü** (`""`), sayaçlar `counts`.
- Tablo: İşletme (+ "Not: `reviewNote`") · Yönetici (ad + telefon) · Başvuru (`formatDay(createdAt)`) · Sipariş · Kullanıcı · Durum pill (`pending` wait "Onay Bekliyor", `active` ok "Aktif", `suspended` hot "Askıda", `rejected` muted "Reddedildi").
- İşlemler:
  - pending: **Onayla** → "Başvuru onaylandı. Firma artık giriş yapabilir." · **Reddet** → onay ("`Ad` başvurusu reddedilsin mi?", "Firmanın kullanıcıları giriş yapamaz. Not firmaya gösterilir.", not alanı "Red nedeni (isteğe bağlı)" ≤300) → "Başvuru reddedildi."
  - active: **Askıya Al** → onay (maddeler: "İşletmenin kullanıcıları hemen giriş yapamaz." · "Bekleyen WhatsApp mesajları iptal olur." · "Kayıtlar silinmez; firma yeniden aktif edilebilir.", not "Askıya alma nedeni (isteğe bağlı)") → "İşletme askıya alındı."
  - suspended/rejected: **Aktif Et** → "İşletme aktif edildi."
  - pending dışı: **İşletmeye Gir** → `POST /platform/switch { businessId }` → `/me` → `/ops` ("İşletmeye girildi.")
- "Yeni işletme aç" formu (`NewAccountFields`) — "Buradan açılan işletme onay beklemeden aktif başlar." → `POST /platform/businesses` → "Yeni işletme açıldı."

## 2. Müşteri puan sayfası — `/r/:token` (`pages/public/PublicRatingPage.jsx`, `RatingSheet.jsx`)

**Neden web'de kalır:** Teslimden sonra müşteriye WhatsApp'tan `PUBLIC_BASE_URL/r/<token>` linki gider. Müşteri uygulamayı yüklemez; link telefonun tarayıcısında açılır. Sunucu (`ccs_server`) `ccs_client/dist`'i aynı alandan servis etmeye devam etmelidir — **web build yayından kaldırılmamalı** (en azından `/r/:token` için). Bkz. 11-yol-haritasi.

Uygulamada yalnız **önizleme** (`/ops/puan-onizleme`) yazılır; aynı görsel bileşenleri kullanır. Bu yüzden bileşenleri burada tanımlıyoruz.

### 2.1 RatingSheet (kart çerçevesi)

```text
┌──────────────────────────────┐
│          (  Y  )             │  ← 46×46 altın daire, işletme adının baş harfi (tr büyük), goldInk
│        Yıldız Halı           │  ← işletme adı, beyaz (yoksa "Yunak")
│      Sayın Ayşe Yılmaz       │  ← sideInk
│         Fiş HK1001           │  ← altın, 13.5
├──────────────────────────────┤  (üst kısım koyu `side` zemin)
│        [ içerik ]            │
└──────────────────────────────┘
```

Sayfa zemini `canvas`, kart beyaz, 18 köşe, `shadow-md`, ortalanmış, max ~440 gen.

### 2.2 StarPicker

- Başlık **"Hizmetimizi puanlayın"**, alt "Bir yıldıza dokunmanız yeterli."
- 5 büyük yıldız, **sıra 5→1** (görsel olarak soldan sağa 5,4,3,2,1 değil; CSS `row-reverse` ile 1..5 soldan sağa görünür ve üzerine gelince soldakiler de dolar). Flutter'da 1..5 soldan sağa çizip seçiliye kadar doldurun. Yıldız 56×56 (telefonda `min(54, 15vw)`), boş renk `line` (#E4E4E7), dolu renk `gold`, seçilince 2px yukarı kalkar; her hücre 64 gen. × 96 yük.
- Her yıldızın altında açıklama (`STAR_CAPTIONS`): 1 "Çok Kötü", 2 "Kötü", 3 "Orta", 4 "İyi", 5 "Mükemmel"; seçili olanın yazısı koyu.
- **Dokunmak hemen gönderir.** (Klavye ile seçimde "N yıldız gönder" düğmesi çıkar — Flutter'da gerekmez.)
- Gönderim sürerken pasif; çift dokunuşta ikinci istek gitmez.

### 2.3 ReasonForm (1–4 yıldız sonrası)

- Başlık **"Üzgünüz, teşekkür ederiz"**, gri kutu "Ne oldu? Birkaç kelime yazarsanız sizi arayıp sorunu çözelim."
- Çoklu seçim çipleri (`FEEDBACK_REASONS`): Leke çıkmadı · Koku var · Teslimat gecikti · Hasar veya deformasyon · Personel · Islaklık veya kalıntı · Başka bir sorun. 44 yük.; seçili çip siyah kenar + kalın.
- "Sorunu yazın (isteğe bağlı)" çok satırlı, ≤**1000**, placeholder "Kısaca yazabilirsiniz", sayaç "`n`/1000".
- **[Gönder]** / "Gönderiliyor…". Göndermek isteğe bağlıdır; yıldız zaten kaydedildi.

### 2.4 Puan sayfası durumları (web referansı)

| `state` | Başlık | Gövde |
| --- | --- | --- |
| loading | — | Yükleniyor… |
| stars | (StarPicker) | |
| reasons | (ReasonForm; önceki seçim ve not dolu gelir) | |
| thanks | Çok teşekkür ederiz! | `googleUrl` (yalnız https) varsa: "Birkaç kelimeyle Google'da yorum yazarsanız bize çok destek olursunuz." + **[Google'da Yorum Yaz]** ve sayfa otomatik oraya gider; yoksa "Değerlendirmeniz bize ulaştı. Yine bekleriz." |
| received | Teşekkürler | Geri bildiriminiz bize ulaştı. En kısa zamanda sizi arayacağız. |
| recorded | Puanınız kaydedildi | Teşekkür ederiz. |
| expired (410) | Bağlantının süresi doldu | Bir sorunuz varsa işletmemizi arayabilirsiniz. |
| limited (429) | Puan kaydedilemedi | Çok fazla deneme. Biraz sonra yeniden deneyin. |
| failed | Puan kaydedilemedi | sunucu mesajı + [Yeniden dene] |
| absent (404) / diğer | Bağlantı bulunamadı | Bu bağlantı artık geçerli değil. |

Kural: 5 yıldız → (sunucu kaydettikten sonra) firmanın Google yorum sayfasına yönlendirme; 1–4 yıldız → "kalkan": müşteri neden yazar, firmaya düşük puan bildirimi gider, Google'a yönlendirilmez.
