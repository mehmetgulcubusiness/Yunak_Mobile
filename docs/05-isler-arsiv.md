# 05 — İşler (Tezgâh), Arşiv, İş kartı, Yeni fiş

## 1. İşler — `/ops` (`pages/ops/DeskPage.jsx`)

Uygulamanın ana ekranı. Kabuk: `section: desk`, `lead: Selam`, `onNew: sheet'i aç`, arama "Ad, telefon veya fiş no ara".

### 1.1 Yerleşim (yukarıdan aşağı)

```text
┌──────────────────────────────────────────────────────────────┐
│ Günaydın, Ayşe              [27 Kasım Cuma]                  │ ← Selam (telefonda sayfa başında)
├──────────┬──────────┬──────────┬───────────────────────────────┤
│AÇIK İŞLER│YIKAMADA  │BUGÜN     │▓ BUGÜNKÜ CİRO (koyu, yönetici)│ ← DayLine (bento)
│ 8        │ 4        │TESLİM 3  │ 5.600 ₺                       │
├──────────┴──────────┴──────────┴───────────────────────────────┤
│ [Açık İşler 8][Teslim Alındı 2][Yıkamada 4][Teslim Edilenler 12]   ● WhatsApp bağlı değil  ● 2 düşük puan … │
│ (Teslim edilenler sekmesinde)  Son 7 günün teslimatları…   Daha eskileri Arşiv'de →                      │
│ MÜŞTERİ & ADRES | HİZMET & İÇERİK | İLETİŞİM & KAYIT | İŞLEM AŞAMASI | TUTAR | AKSİYON  (masaüstü)       │
│ OrderCard …                                                                                         │
│ OrderCard …                                                                                         │
└──────────────────────────────────────────────────────────────┘
  Toplam 120 kayıttan 1–50 arası gösteriliyor   [← Önceki] Sayfa 1 / 3 [Sonraki →]
```

### 1.2 Selam

- `greeting(now)` (İstanbul saatine göre): 05–12 **"Günaydın"**, 12–18 **"İyi günler"**, diğer **"İyi akşamlar"** + `, <ilk ad>`.
- Yanında tarih çipi: `formatToday(now)` → "27 Kasım Cuma" (`tr-TR` sırası; Dart: `DateFormat("d MMMM EEEE", "tr")`).

### 1.3 DayLine — günün rakamları (`dashboard.kpis`)

| Kart | Değer | Alt yazı | İkon |
| --- | --- | --- | --- |
| Açık işler | `activeOrders` | Aktif işlem gören fişler | desk |
| Yıkamada | `washingOrders` | Atölyede devam eden | drops |
| Bugün teslim | `deliveredToday` | Bugün teslim edilen | check |
| **Bugünkü ciro** (koyu kart) | `money(revenueToday)` | Bugün teslim edilen işlerden | till |

Ciro kartı yalnız `revenueToday` **sayı** ise görünür (personele `null` gelir) → o zaman 3 kart. Telefonda 2×2 ızgara.

### 1.4 Sekmeler

| Sekme (`tab`) | Etiket | Sayaç (`dashboard.tabs`) | Not |
| --- | --- | --- | --- |
| `open` (varsayılan) | Açık İşler | `open` | |
| `collected` | Teslim Alındı | `collected` | |
| `washing` | Yıkamada | `washing` | |
| `delivered` | Teslim Edilenler | `delivered` | ipucu "Son 7 gün" |

Geçersiz `tab` → `open`. Sekme değişince `q` korunur, `page` sıfırlanır.

### 1.5 Yapılacaklar (Todos) — sekmelerin yanında

Yalnız yapılacak bir şey varsa görünür. Sırayla:

| Koşul | Ton | Metin | Dokununca |
| --- | --- | --- | --- |
| `!tenant.whatsappBound` | bad | WhatsApp bağlı değil | yönetici: `/ops/ayarlar`, personel: dokunulmaz |
| bağlı ve `queue.failed + queue.uncertain > 0` | bad | `N` mesaj ulaşmadı | yönetici: `/ops/ayarlar` |
| `dashboard.overdue > 0` | bad | `N` iş teslim sözünü aştı | yönetici: `/ops/analiz#geciken`, personel: `/ops/servis` |
| `dashboard.openCrises > 0` | warn | `N` düşük puan bekliyor | `/ops/degerlendirmeler?filter=unresolved` |
| yönetici ve kurulum eksik | plain | Kurulumu tamamlayın (`x`/3) | `/ops/ayarlar` |

Kurulum 3 adım: `tenant.whatsappBound`, `tenant.setup.googleReview`, `tenant.setup.iban`.

Telefonda yatay kaydırılan tek satır.

### 1.6 Liste

- `GET /api/orders?tab=&q=&page=`
- Yükleniyor (ilk) → `CardSkeleton` (3 iskelet kart).
- `ListState`:
  - boş: `delivered` ise **"Son 7 günde teslim edilen iş yok."**, değilse **"Açık iş yok. Yeni bir iş için “Yeni fiş” düğmesine basın."**
  - arama boş: **"Aramaya uyan fiş yok."** + "Farklı bir ad, telefon veya fiş numarası deneyin."
- `delivered` sekmesinde:
  - Not satırı: `q` varsa "Arama bütün teslimatlarda yapıldı.", yoksa "Son 7 günün teslimatları, teslim gününe göre." + sağda **"Daha eskileri Arşiv'de →"** (`/ops/arsiv?q=…`).
  - Kartlar **DayGroups** ile gün bantlarına bölünür (bkz. 09).
- Diğer sekmeler: düz `OrderCard` listesi.
- Masaüstünde liste üstünde sütun başlıkları (`BoardCols`): MÜŞTERİ & ADRES · HİZMET & İÇERİK · İLETİŞİM & KAYIT · İŞLEM AŞAMASI · TUTAR · AKSİYON. Telefonda yok.
- Altta `Pager`.

### 1.7 Yenileme

`refreshAll = Future.wait([orders.reload(silent), suggestedReference.reload(silent), reloadDashboard()])`

- Her kart işleminden sonra.
- **45 sn**'de bir otomatik (uygulama ön plandayken), ön plana dönünce, bağlantı gelince.
- Flutter'da ayrıca `RefreshIndicator` (aşağı çekince yenile) ekleyin.

### 1.8 Derin bağlantılar

| Parametre | Davranış |
| --- | --- |
| `?new=1` | Yeni fiş sheet'ini boş aç, parametreyi sil |
| `?fill=<customerId>` | `GET /api/customers/:id` → formu o müşteriyle doldur (`fill(card)`) → sheet'i aç → parametreyi sil. Hata: kırmızı toast "Müşteri kartı açılamadı; boş fiş açabilirsiniz." |
| `?notice=forbidden` (web'de `state.notice`) | Kırmızı toast "Bu sayfaya yalnızca yöneticiler girebilir." |
| `?q=<fişno>&tab=…` | Diğer sayfalardan "İş kartına git" |

### 1.9 Müşteri kartı ve yeni fiş

- Karttaki müşteri adına dokununca `CustomerDrawer(customerId)` açılır (bkz. 06). Drawer'daki **"Yeni Fiş Aç"** → formu doldur, drawer'ı kapat, sheet'i aç.
- **Yeni fiş sheet'i** (`Sheet`, başlık **"Yeni Fiş"**): içinde `IntakeForm`. Sheet kapatılınca içerik **silinmez** (yanlışlıkla kapanan formdaki yazılar kalır) → Flutter'da form state'ini sheet'in dışında (provider/`GlobalKey`) tutun. Telefonda tam ekran, masaüstünde sağdan panel.
- Fiş açılınca: sheet kapanır, `refreshAll()`.

---

## 2. Arşiv — `/ops/arsiv` (`pages/ops/ArchivePage.jsx`)

Kabuk: başlık **"Arşiv"**, alt "Teslim edilen bütün işler, teslim gününe göre", `onNew` → `/ops?new=1`, arama "Arşivde ad, telefon veya fiş no ara".

- `GET /api/orders?tab=archive&q=&page=&month=`
- **Ay çipleri** (`months` varsa, yatay): **"Tümü `tabs.archive`"** + her ay `monthLabel("2026-11")` = "Kasım 2026" + adet. Seçili çip vurgulu. Ay seçilince `page` sıfırlanır, `q` korunur.
- Liste: her zaman `DayGroups` + `OrderCard`.
- Boş: ay seçiliyse **"Bu ayda teslim edilen iş yok."**, değilse **"Henüz teslim edilen iş yok."**; arama boş: **"Aramaya uyan teslimat yok."**
- Müşteri drawer'ında "Yeni Fiş Aç" → `/ops?fill=<id>`.
- Otomatik yenileme yok; işlem sonrası `orders.reload(silent) + reloadDashboard()`.

---

## 3. İş kartı — `OrderCard` (`components/OrderCard.jsx`)

Tek fiş. Bütün işlemler API'ye gider, sonra `onChanged()` listeyi yeniler.

### 3.1 Türetilen durumlar

```dart
final service   = serviceOf(order.serviceType);
final finished  = order.status == 'delivered' || order.status == 'completed';
final cancelled = order.status == 'cancelled';
final closed    = finished || cancelled || order.voided;
final next      = (order.voided || cancelled) ? null : primaryMove(order, order.moves);
final extras    = (order.voided || cancelled) ? [] : order.moves.where((m) => m.to != next?.to);
final address   = (order.address ?? '').trim();
final extraNote = order.deskNote?.trim() != address ? order.deskNote?.trim() ?? '' : '';
final canAmend  = !closed || manager;           // biten/iptal/geçersiz işte yalnız yönetici
final canMessage= !cancelled && !order.voided;
final stuck     = order.whatsappStuck && canMessage;
final previewLink = order.previewToken matches ^[A-Za-z0-9_-]{43}$;
```

`primaryMove` (ana büyük düğme):

| Mevcut durum | Ana adım |
| --- | --- |
| `received` | `washing` |
| `draft` | `scheduled` (yoksa ilk move) |
| `scheduled` | `in_progress` (yoksa ilk move) |
| `washing` / `in_progress` | `delivered` veya `completed` |
| diğer | yok |

Ana düğme yazısı (`bigLabel`): `washing` **"Yıkamaya Al →"** · `in_progress` **"İşe Başla →"** · `delivered` **"Teslim Et →"** · `completed` **"İşi Bitir →"** · `scheduled` **"Randevu Ver →"** (outline stil). Diğer → `MOVE_LABELS`.

Sol şerit / aşama (`stageOf`): `received`→collected, `washing|in_progress`→washing, `delivered|completed`→done, `draft|scheduled`→booked. Düşük puan varsa kart `crisis` (vurgulu), iptal/geçersizse `closed` (soluk zemin, ad ve tutar `muted`).

### 3.2 Kartın içeriği

| Bölge | İçerik |
| --- | --- |
| **who** | Hizmet karosu (ikon) · **müşteri adı** (dokununca drawer) · `#REF` (fiş no) · alt satır: adres (dokununca Google Maps arama `mapsHref`) ya da "Adres yok" |
| **svc** | **Hizmet adı** (Halı Yıkama…) · alt satır: `extraNote` ya da "—" |
| **contact** | Telefon `0532 111 00 31` (dokununca `tel:`) · alt satır: bugünse "Bugün 14:05", değilse "27 Kas 2026" + varsa " • `actorName`" |
| **now** | İptal → pill "İptal edildi"; geçersiz → pill "Geçersiz sayıldı"; diğer → `Stepper` |
| **amount** | `money(amount)` ya da "—" + alt: kasa notu |
| **next** | Ana düğme / Geri al · "★ Yıldız İste" (bitmiş ve mesaj gidebilir) · "⋯" menü |
| **extra** (varsa, tam genişlik) | WhatsApp hatası bandı · düşük puan bandı · tutar düzenleme formu · test linki |

Kasa notu (`cashNote`): iptal/geçersiz → "Kasaya sayılmaz"; bitmiş → "Kasaya yazıldı"; `amount == null` → "Fiyat girilmedi"; diğer → "Teslimde kasaya".

Telefon düzeni (≤640): üst satır who (sağ üstte tutar), sonra svc | contact (iletişim sağa yaslı), sonra Stepper (altında çizgi), en altta düğmeler tam genişlik (44 yük.).

### 3.3 Ek bantlar

- **WhatsApp hatası** (`stuck`): kırmızı bant "WhatsApp mesajı gitmedi." + **[Tekrar Gönder]** → `POST /orders/:id/retry`:
  - `requeued > 0` → yeşil "Mesaj yeniden gönderildi."
  - değilse kırmızı "Gönderilecek mesaj bulunamadı."
- **Düşük puan** (`feedback`): sarı bant "Müşteri `N` yıldız verdi. “not”"
- **Test linki** (`previewLink`): "Müşteri Yıldız Ekranını Aç (Test)" → tarayıcıda `<web-kök>/r/<token>`. Yalnız geliştirme sunucusunda dolu gelir.

### 3.4 Geri alınabilir durum ilerletme (önemli)

Ana düğmeye ya da menüdeki bir adıma basınca istek **hemen gitmez**:

1. Düğme **"↶ Geri al · 5"** olur, her saniye sayı azalır (altın çubuk boşalır). Erişilebilirlik metni: "`Yıkamaya alındı` olarak N saniye sonra kaydedilecek."
2. 5 sn içinde dokunulursa iptal → yeşil toast **"İşlem geri alındı."**
3. Süre dolunca `POST /orders/:id/advance { to }` → başarı toast `"<DONE_LABEL>: #REF"`:
   `washing` "Yıkamaya alındı", `delivered` "Teslim edildi", `scheduled` "Randevu verildi", `in_progress` "İşe başlandı", `completed` "İş bitti" (yoksa "Durum güncellendi").
4. **Kart ekrandan kalkarsa** (sekme değişti, sayfa kapandı) bekleyen ilerletme **hemen gönderilir** (`dispose` içinde fire-and-forget).
5. Bekleme sürerken "⋯" menüsü kilitli; uygulamadan çıkış uyarısı (`useUnsavedGuard`) açık.

Flutter: `StatefulWidget` içinde `Timer.periodic(1s)`; `dispose()`'da `if (pending != null) ordersApi.advance(...).ignore()`. `ListView` öğeleri ekran dışına kayınca dispose olabilir → **`AutomaticKeepAliveClientMixin`** kullanın ya da bekleyen işlemleri kart dışında (provider) tutun, aksi halde kaydırınca istek erken gider.

Hata kodları `illegal_transition`, `not_cancellable`, `not_voidable`, `invalid_status` gelirse (başkası değiştirmiş) toast + `onChanged()` (liste yenilenir).

### 3.5 "★ Yıldız İste"

Görünür: `finished && canMessage`. `POST /orders/:id/rating-request`:
- `outcome == 'queued'` → yeşil "Puan linki müşteriye gönderiliyor."
- değilse kırmızı "Puan linki gönderilmedi. " + `SKIP_REASON_LABELS[reason]` (bkz. 10).

### 3.6 "⋯" menüsü (`MoreMenu`)

Sırayla, koşula göre:

| Öğe | Koşul | İşlem |
| --- | --- | --- |
| Tutar ve Not Düzenle | `canAmend` | düzenleme formunu aç |
| Fişi Yazdır | her zaman | `PrintSlip` |
| IBAN Gönder | `canMessage` | `POST /orders/:id/send-iban` → "IBAN müşteriye gönderiliyor." |
| (extras) | her ek move | `delivered` ise **"Yıkamadan Teslim Et"**, değilse `MOVE_LABELS[to]` → geri alınabilir ilerletme |
| İşi İptal Et (kırmızı) | `order.cancellable` | onay → `POST /orders/:id/cancel` → "İş iptal edildi." |
| Teslimatı Geçersiz Say (kırmızı) | `order.voidable && manager` | onay → `POST /orders/:id/void` → "Teslimat geçersiz sayıldı." |

Onay pencereleri:

- **İptal:** başlık "`#REF` iptal edilsin mi?", gövde "İş iptal edilir, bekleyen mesajları gönderilmez.", düğme "İşi İptal Et" (tehlikeli).
- **Geçersiz say:** başlık "`#REF` teslimatı geçersiz sayılsın mı?", gövde "Durum değişmez. Şunlar olur:", maddeler: "Gönderilmemiş WhatsApp mesajları düşer." · "Fiş kasa ve müşteri toplamlarına girmez." · "Puan linki gönderilmez.", düğme "Geçersiz Say" (tehlikeli).

Flutter: masaüstünde `MenuAnchor`/`PopupMenuButton`, telefonda `showModalBottomSheet` listesi daha rahattır.

### 3.7 Tutar ve not düzenleme formu (kart içinde açılır)

Alanlar (3 sütun; telefonda 2 + tam genişlik):

| Alan | Etiket | Kural |
| --- | --- | --- |
| area | hizmet birimi: **"m²"** (halı, perde) / **"Adet"** (koltuk, yorgan) | `filterAmount`; boş bırakılabilir |
| rate | **"m² Fiyatı ₺"** / **"Birim Fiyat ₺"** | `filterAmount` |
| amount | **"Toplam Tutar (₺)"** (`AmountField`, önizlemeli, otomatik odak) | `parseAmount`; area×rate doluysa otomatik hesaplanır |
| note | **"Kısa Not"** (tam genişlik), placeholder "Kapı kodu, teslim notu", ≤160 | `checkLine(note, 160, "Not")` |

- Açılırken: `amount = amountField(order.amount)` ("1.250,50"; tam sayıysa "1.250"), `note = order.deskNote`, area/rate boş.
- area veya rate değişince: `meterTotal(area, rate)` null değilse `amount = formatAmount(parseAmount(total).value)`.
- `meterProduct(area, rate) > 1.000.000` → amount hatası **"Toplam 1.000.000 ₺'yi geçiyor."** (kaydederken "…geçemez.").
- **[Kaydet]** → `PATCH /orders/:id/quote { amount: amountWire(value) (boşsa ""), note }` → "Tutar ve not güncellendi." → formu kapat. Sunucu hatası alana düşer.
- **[Vazgeç]** formu kapatır.

---

## 4. Yeni fiş formu — `IntakeForm` (`components/IntakeForm.jsx`)

Sıra tezgâhtaki konuşmayla aynıdır: hizmet → telefon (kayıtlı müşteri kendiliğinden gelir) → ad → tutar → adres → not → fiş no.

### 4.1 Alanlar

| # | Alan | Etiket | Ayrıntı |
| --- | --- | --- | --- |
| 1 | service | (gizli legend "Hizmet") | 4 seçenekli radyo kart: **Halı** · **Koltuk** · **Yorgan** · **Perde** (ikonlu). Varsayılan `carpet_wash` |
| 2 | phone | **Cep Telefonu** * | `PhoneField`, otomatik odak. Odaktan çıkınca kayıtlı müşteri araması |
| — | (bilgi) | | Kayıtlıysa: "Kayıtlı müşteri: **Ad**"; mesajları kapalıysa sarı uyarı "Bu müşteri WhatsApp mesajlarını kapattı. Fiş açılır ama mesaj gitmez." |
| 3 | name | **Müşteri Adı Soyadı** * | placeholder "Ayşe Yılmaz", ≤120, odaktan çıkınca `checkPersonName` |
| 4 | area | **m²** / **Adet** | `filterAmount`, odaktan çıkınca `parseAmount` hatası |
| 5 | rate | **m² Fiyatı ₺** / **Birim Fiyat ₺** | aynı |
| 6 | amount | **Toplam Tutar (₺)** | `AmountField` (önizlemesiz); area×rate ile otomatik |
| 7 | address | **Adres** | placeholder "İlçe, mahalle, açık adres", ≤240 |
| 8 | note | **Kısa Not** | placeholder "Kapı kodu, teslim notu", ≤160 |
| 9 | reference | **Fiş / Sipariş No** | ipucu "Otomatik verilir, isterseniz değiştirin." Değer: kullanıcı yazdıysa o, yoksa `suggestedReference`. `filterReference` (BÜYÜK harf, Türkçe→ASCII, yalnız A-Z 0-9 -), ≤32, `textCapitalization.characters`, otomatik düzeltme kapalı |
| — | düğme | **"Fişi Oluştur"** / "Kaydediliyor…" | tam genişlik, büyük, sheet'in altına sabit |

Hizmet birimi: `serviceOf(service).unit` (`m²` veya `Adet`).

### 4.2 Kayıtlı müşteri araması (telefon odaktan çıkınca)

```text
e164 = parsePhone(phone)
yoksa → known = null; telefon doluysa hata "Geçerli bir cep telefonu girin (05xx xxx xx xx)."
varsa → GET /api/customers?q=<e164'ün +90'sız hali, ör. 5321110031>&page=1
         match = items.firstWhere(row.phone == e164)
         known = match
         match varsa: name = match.name; address boşsa address = match.address
```

Telefon her değiştiğinde arama "ticket"ı artırılır; geç gelen eski cevap yeni numaranın üstüne yazılmaz. `fill(card)` de ticket artırır.

### 4.3 `fill(card)` (dışarıdan doldurma)

`name = card.name (≤120)`, `phone = maskPhone(displayPhone(card.phone))`, `address = card.address (≤240)`, `note = ""`, `known = null`, hatalar temizlenir. Hizmet, tutar alanları korunur.

### 4.4 Gönderim

1. Doğrula (`runChecks`):
   - reference → `checkReference(shownReference)`
   - name → `checkPersonName`
   - phone → `checkPhone`
   - amount → area×rate > 1.000.000 ise "Toplam 1.000.000 ₺'yi geçemez.", değilse `parseAmount(amount)` (boş geçerli → null)
   - address → `checkLine(address, 240, "Adres")`
   - note → `checkLine(note, 160, "Not")`
2. `POST /api/orders`:
   ```json
   { "service": "carpet_wash", "name": "Ayşe Yılmaz", "phone": "+905321110031", "reference": "HK1043",
     "amount": "1250,5", "address": "…", "note": "…", "allowDuplicate": true /* yalnız onaydan sonra */ }
   ```
3. Başarı toast'ı (birleştirilir):
   - `replay` → "Bu fiş az önce açılmıştı."
   - `messagesSuppressed` → "İş açıldı. Bu müşteriye mesaj gitmez."
   - diğer → "İş açıldı."
   - `+` dönen `reference` gönderilenden farklıysa " `X` doluydu, `Y` verildi."
   - `+` `existingCustomer.name` girilen addan farklıysa " Müşteri kayıtlı adıyla (`Ad`) açıldı."
4. Başarıda form sıfırlanır **ama hizmet seçimi korunur**; elle yazılan fiş no silinir (yeni öneri gelir); `onOpened()`.
5. Hatalar:
   - `duplicate_today` → toast yok; onay penceresi: başlık **"Bu müşteriye bugün fiş açıldı"**, gövde "`Ad` için bugün #`extra.reference` açıldı. Yine de yeni bir fiş açılsın mı?", düğme **"Yine de Aç"** → `allowDuplicate: true` ile tekrar.
   - `reference_taken` → fiş no alanı hatalı; `extra.suggested` varsa alanın altında **"`X` numarasını kullan"** düğmesi; yoksa `GET /orders/suggested-reference` ile yeni öneri alınıp aynı düğme gösterilir.
   - diğerleri → alana eşlenirse alanın altında, değilse toast. Form korunur.

Kaydedilmemiş veri: name/phone/amount/address/note/area/rate'ten biri doluysa kirli.
