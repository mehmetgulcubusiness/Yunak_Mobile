# 06 — Müşteriler, Müşteri kartı, Yorumlar, Puan önizleme

## 1. Müşteriler — `/ops/musteriler` (`pages/ops/CustomersPage.jsx`)

Kabuk: başlık **"Müşteriler"**, alt **"`total` kayıtlı müşteri"** (yüklenene kadar boş), arama "Ad, telefon veya adres ara". `onNew` yok (alt çubuk + → `/ops?new=1`).

- `GET /api/customers?q=&page=`
- **Masaüstü tablo** sütunları: Ad Soyad · Telefon · Adres · Sipariş (sağa yaslı) · Toplam (sağa) · Son sipariş
- **Telefonda** her satır bir kart; hücreler "Etiket: değer" (`cards-on-phone`).

| Hücre | İçerik |
| --- | --- |
| Ad Soyad | Monogram + **ad** (dokununca `CustomerDrawer`) + `optedOut` ise pill **"Mesaj kapalı"** (muted) |
| Telefon | `displayPhone(phone)`, dokununca `tel:+<rakamlar>` |
| Adres | `address ?? "—"` |
| Sipariş | `orderCount` |
| Toplam | `money(totalTry) ?? "0 ₺"` |
| Son sipariş | `formatDay(lastOrderAt)` ya da "—" |

- Yükleniyor → tablo iskeleti (6 sütun, 4 satır).
- Boş: **"Henüz müşteri yok. İlk fişi açtığınızda müşteri buraya eklenir."**; arama boş: **"Aramaya uyan müşteri yok."**
- `Pager(noun: "müşteri", nounFrom: "müşteriden")`.
- Drawer "Yeni Fiş Aç" → `/ops?fill=<id>`; drawer değişiklik yapınca liste sessiz yenilenir.

---

## 2. Müşteri kartı — `CustomerDrawer` (`components/CustomerDrawer.jsx`)

Masaüstünde sağdan açılan panel, telefonda tam ekran. Flutter: geniş ekranda `showGeneralDialog` ile sağdan kayan `Align(right)` panel; telefonda `Navigator.push(fullscreenDialog: true)` veya `DraggableScrollableSheet`.

Props: `customerId`, `onClose`, `onChanged`, `onFill?(card)` (verilmezse "Yeni Fiş Aç" düğmesi yok ve aksiyon satırı 3'lü).

### 2.1 Yükleme

`GET /api/customers/:id`.
- Yükleniyor → iskelet (2 satır + blok).
- Hata/boş → başlık **"Müşteri bulunamadı"**, gövde "Kayıt silinmiş ya da bu işletmeye ait değil." + ×.

### 2.2 Üst kısım

- Büyük Monogram · **Ad** (başlık) · sadakat etiketi `loyaltyOf(orderCount)`:
  - ≥5 → **"★ Sadık müşteri"** (altın)
  - ≥2 → "Tekrar gelen"
  - diğer → "Yeni müşteri"
- Altında telefon (`displayPhone`). Sağda × kapat.
- Adres satırı (📍): varsa adres; yoksa dokunulabilir **"Adres eklenmemiş · Ekle"** → düzenleme formunu açar.
- `optedOut` → sarı uyarı "Bu müşteriye WhatsApp mesajı gitmiyor."

### 2.3 Aksiyon satırı

| Düğme | İşlem |
| --- | --- |
| **+ Yeni Fiş Aç** (birincil; `onFill` varsa) | `onFill(card)` |
| **Ara** | `tel:+<rakamlar>` |
| **WhatsApp** | `https://wa.me/<rakamlar>` (dış uygulama) |
| **IBAN Gönder** | `optedOut` ise pasif (ipucu "Bu müşteriye mesaj gitmiyor."); `POST /customers/:id/send-iban` → "IBAN müşteriye gönderiliyor." |

### 2.4 KPI'lar (3 kutu)

Sipariş `orderCount` · Toplam `money(totalTry) ?? "0 ₺"` · Son puan `lastStars ? "N ★" : "—"`.

### 2.5 Fişler

Başlık "Fişler `orders.length`". Boşsa "Bu müşterinin henüz fişi yok." İlk **3** fiş gösterilir; fazlası varsa **"Tümünü göster (N)"** / **"Daha az göster"**.

Fiş kartı (`SlipCard`):
- Ton: iptal/geçersiz → muted; bitmiş → ok; diğer → open.
- Üst: `#REF` + **hizmet adı** · sağda `money(amount) ?? "—"` + durum etiketi (`voided` ise "Geçersiz", değilse `STATUS_LABELS[status]`).
- Gövde: not varsa "• not"; "27 Kas 2026 14:05 · actorName".
- Alt: muted ise "Kasaya sayılmaz"; değilse **"İş kartına git →"** → `/ops?tab=<bitmişse delivered, değilse open>&q=<REF>` (drawer kapanır). Sağda **"🖨 Fişi Yazdır"** (`PrintSlip`; müşteri adı/telefon/adres karttan, `deskNote = order.note`).

### 2.6 Müşteri notu (yalnız işletme görür)

- Not yoksa: "＋ Müşteri veya adres notu ekle…" kutusu.
- Not varsa: 📝 not metni + "Düzenle".
- Düzenleme: çok satırlı alan (3 satır, ≤**500**), placeholder "Örn. Teslimattan önce aranacak, kapıda nakit ödeme.", sayaç "`n`/500 · Müşteriye gönderilmez", [Vazgeç] [Kaydet] (değişmediyse Kaydet pasif).
- `PUT /customers/:id/note { note }` → boşsa "Not silindi.", doluysa "Not kaydedildi." Cevap kart dönerse onu kullan, dönmezse yerelde `note = trim() || null`.

### 2.7 Bilgileri düzenle

Alt kısımda (düzenleme kapalıyken) küçük düğmeler:
- **✎ Bilgileri düzenle**
- `optedOut` ise **"Mesajları aç"**, değilse **"🔇 Mesajları kapat"**
- (yönetici) sağda kırmızı **"🗑 Kaydı sil"** (ipucu "Ad, telefon ve adres silinir.")

Form: **Ad Soyad** * (≤120) · **Telefon** * (PhoneField) · **Açık Adres** (≤240). [Kaydet] (değişmediyse pasif) [Vazgeç].
- Doğrulama: `checkPersonName`, `checkPhone`, `checkLine(address, 240, "Adres")`.
- `PUT /customers/:id { name, phone (E.164), address }` → "Müşteri bilgileri kaydedildi." Cevap kartsa birleştir; form normalleşmiş değerlere eşitlenir; `onChanged()`.

### 2.8 Onaylar

| İşlem | Başlık | Gövde | Düğme | Sonra |
| --- | --- | --- | --- | --- |
| Mesajları kapat | Mesajlar kapatılsın mı? | `Ad` adlı müşteriye bundan sonra hiçbir WhatsApp mesajı gitmez (fiş, IBAN, puan linki). | Mesajları Kapat (tehlikeli) | `POST opt-out` → "Bu müşteriye artık mesaj gitmez." → kartı yeniden yükle |
| Mesajları aç | Mesajlar yeniden açılsın mı? | Bunu yalnız `Ad` izin verdiyse yapın. Yeni işlerde bilgilendirme mesajları yeniden gider. | Mesajları Aç | `POST opt-in` → "Bu müşteriye yeniden mesaj gidecek." → yeniden yükle |
| Kaydı sil (KVKK) | Müşteri kaydı silinsin mi? (KVKK) | Bu işlem geri alınamaz. Silinecekler: · Ad soyad · Telefon (`0532…`) · Kayıtlı adres · Müşteri notu ve fiş notları · Müşterinin yorum notları · Bekleyen WhatsApp mesajları | Kalıcı Olarak Sil (tehlikeli) + **müşterinin adını yazmadan açılmaz** | `DELETE /customers/:id` → "Müşteri kaydı silindi." → drawer kapanır |

Kaydedilmemiş veri: form ya da not taslağı kirliyse kapatırken onay.

---

## 3. Yorumlar — `/ops/degerlendirmeler` (`pages/ops/RatingsPage.jsx`)

Kabuk: başlık **"Yorumlar"**, alt "Müşterileriniz işinizi nasıl puanladı", arama "Ad, telefon, fiş no veya şikâyet ara".

- `GET /api/ratings?filter=&q=&page=`; **60 sn** otomatik sessiz yenileme.
- Masaüstü: solda liste, sağda özet rayı. Telefonda özet üstte kompakt.

### 3.1 Filtre çipleri (`filter`)

| Değer | Etiket | Sayaç |
| --- | --- | --- |
| `all` (varsayılan; sunucuya gönderilmez) | Tümü | `summary.total` |
| `unresolved` | Bekleyen şikâyetler | `summary.openCrises` |
| `shield` | 1–4 yıldız | `summary.shieldCount` |
| `google` | 5 yıldız | `summary.googleCount` |
| `resolved` | Çözülenler | `summary.resolvedCount` |

Sonda bağlantı: **"Müşterinin gördüğü ekranı aç"** → `/ops/puan-onizleme`. Telefonda çipler yatay kaydırılır.

### 3.2 Puan kartı (`RatingCard`)

- `happy = route == 'google'`; `open = !happy && !resolved` (kart vurgulu).
- Üst: Monogram · **ad** · 5 altın yıldız (dolu sayısı = `round(stars)`, 0–5) · `open` ise pill bad **"Aranmayı bekliyor"** · `resolved` ise pill ok **"Çözüldü"**.
- Meta: hizmet ikonu + adı · `#REF` · telefon (`tel:`) · `formatStamp(submittedAt)` ("27.11.2026 14:05").
- Nedenler: etiketler (`FEEDBACK_REASONS` kodundan etikete).
- Not: tırnaklı alıntı.
- `open` ise sağ/alt aksiyonlar: **"WhatsApp'tan Yaz"** (`wa.me`) · **"Çözüldü"** (birincil) → `POST /ratings/:id/resolve` → "Şikâyet çözüldü olarak işaretlendi." → liste + dashboard yenilenir.

Boş: filtre `all` ise **"Henüz puan gelmedi. İş teslim edildikçe müşterilerinize puan linki gider."**, değilse **"Bu listede kayıt yok."**; arama boş: **"Aramaya uyan puan yok."**. `Pager(noun: "puan", nounFrom: "puandan")`. Yükleniyor → 2 iskelet kart.

### 3.3 Özet rayı

- Büyük ortalama: `average.toFixed(1)` virgüllü ("4,6"); yoksa "—". Altında yıldızlar ve "`total` değerlendirme".
- Dağılım çubukları 5★→1★: genişlik `count / max(count)`; renk 4–5 yüksek (yeşil), 3 orta (sarı), 1–2 düşük (kırmızı); sağda adet.
- İstatistikler: Bekleyen şikâyet `openCrises` · Çözülen şikâyet `resolvedCount` · 5 yıldız veren `googleCount`.

---

## 4. Puan ekranı önizleme — `/ops/puan-onizleme` (`pages/public/RatingPreviewPage.jsx`)

Panelden açılan, **sunucuya hiçbir şey yazmayan** önizleme. Müşterinin `/r/:token`'da göreceğini örnek verilerle gösterir. Kabuk **olmadan** tam ekran (`RatingSheet` görünümü).

Örnek fiş: müşteri "Ayşe Yılmaz", fiş "HK1001", işletme `me.tenant.name ?? "İşletme"`.

Akış (yerel durum):
1. `StarPicker` → yıldız seç.
2. 5 ★ → "Çok teşekkür ederiz!" / "Birkaç kelimeyle Google'da yorum yazarsanız bize çok destek olursunuz. (Önizlemede Google'a gidilmez.)" / [Baştan Başla].
3. 1–4 ★ → `ReasonForm` → Gönder → başa dön.

Görsel ve bileşen ayrıntıları: [08-platform-ve-puan-sayfasi.md › RatingSheet](08-platform-ve-puan-sayfasi.md#2-müşteri-puan-sayfası--rtoken).
