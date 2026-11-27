# 07 — Kasa, Analiz, Servis listesi, Ayarlar

Kasa, Analiz ve Ayarlar **yalnız yönetici** (`admin`/`super_admin`); personel girerse `/ops`'a döner ve "Bu sayfaya yalnızca yöneticiler girebilir." görür. Servis listesi herkese açıktır.

## 1. Kasa — `/ops/kasa` (`pages/ops/CashPage.jsx`)

Kabuk: başlık **"Kasa"**, alt yazı `periodTitle`, aksiyonlar **"📝 Excel'e aktar"** ve **"🖨 Yazdır"**.

- `GET /api/cash?period=` (bu ay için `period` gönderilmez).
- `periodTitle`: `today` → "Bugün · 27 Kas 2026"; `week` → "Son 7 gün"; `month` → "`Kasım 2026` (bugüne kadar)" (`period.start`'tan); `YYYY-MM` → `monthLabel`.

### 1.1 Dönem seçici

Segment: **Bugün** (`today`) · **Son 7 gün** (`week`) · **Bu ay** (`month`, varsayılan). Yanında `months` içinden bu aydan önceki aylar varsa **"Geçmiş ay"** açılır listesi: "Seçin" + "`Ekim 2026` (`40` teslim)". Seçim URL'de `period`.

Karşılaştırma metni (`COMPARE`): `today` "düne göre" · `week` "önceki 7 güne göre" · `month` "geçen ayın aynı günlerine göre" · geçmiş ay "bir önceki aya göre".

### 1.2 Özet kartları (bento, 4'lü)

| Kart | Değer | Alt |
| --- | --- | --- |
| **Ciro** (koyu) | `money(summary.totalTry)` | `Change(totalTry, previous.totalTry)` |
| Teslim edilen iş | `summary.count` | `Change(count, previous.count)` |
| Ortalama fiş | `money(summary.averageTry)` | Teslim edilen iş başına |
| İçerideki iş | `money(inside.totalTry)` | `inside.count` fiş henüz teslim edilmedi |

`Change(now, before)`:
- `before` 0/boş → `now > 0` ise "Önceki dönemde teslim yok", değilse "Henüz teslim yok" (gri).
- değilse `ratio = round((now-before)/before*100)` → "▲ %12 düne göre" (yukarı yeşil) / "▼ %8 …" (kırmızı) / "■ %0 …" (gri). Yön her zaman ok + yazı ile, yalnız renkle değil.

Yükleniyorken değerlerin yerinde iskelet çizgi.

### 1.3 Dikkat satırları (varsa)

- `summary.unpriced > 0` → (sarı) "🚩 **`N` iş fiyatı girilmeden teslim edildi** · ciroya 0 ₺ olarak girdi"
- `summary.voided.count > 0` → "🚩 **`N` teslim geçersiz sayıldı** · `money(voided.totalTry)` ciroya girmedi"
- `summary.cancelled > 0` → "🚩 **`N` iş iptal edildi**"

### 1.4 Günlük ciro grafiği

Panel başlığı: `today` ise "Son 7 günün cirosu", değilse "Günlük ciro"; sağda "`N` günde teslim var".

- Tek seri dikey çubuk. Yükseklik `totalTry/peak` (0 değilse en az %4).
- **Bugün altın**, `future` günler soluk (dokunulmaz).
- X ekseni: 7 gün ise "Bugün" / kısa gün adı ("Pzt"); ay ise yalnız 1, 5'in katları ve son gün.
- Dokununca/üstüne gelince: "**1.250 ₺** · 27 Kas 2026 · 3 fiş".
- Altta "En yüksek gün: `money(peak)`" + "■ Bugün" lejantı.

Flutter: `fl_chart` `BarChart`, `BarTouchData` tooltip.

### 1.5 Hizmetlere göre / Personel

**Hizmetlere göre** (yalnız `count > 0`): hizmet karosu · **ad** · sağda `money(totalTry)` · pay çubuğu · "`N` fiş · ortalama `X` · cironun %`P`'i" (`P = round(100*total/servicesTotal)`). Boşsa "Bu dönemde teslim edilen iş yok."

**Personel** tablosu: Personel (`name ?? "Ortak hesap"`) · Açtığı fiş · Teslim ettiği · Teslim tutarı. Boşsa "Bu dönemde personel hareketi yok."

### 1.6 En çok kazandıran müşteriler / İçerideki iş

**En çok kazandıran müşteriler** (sıralı liste): sıra no · **ad** (dokununca `/ops/musteriler?q=<ad>`) · "`N` fiş" · `money(totalTry)`. Boşsa "Bu dönemde tutarı girilmiş teslim yok."

**İçerideki iş**: `inside.stages` → `collected` "Teslim alındı", `washing` "Yıkamada / işlemde", `booked` "Randevu bekleyen" · "`N` fiş" · tutar. Notlar: `inside.unpriced > 0` → "🚩 `N` açık işin fiyatı girilmedi; toplam eksik görünür." · `oldestDays != null` → "🕒 En eski fiş `bugün açıldı` / `N gündür içeride`."

Sayfa sonu ipucu: "Ciro teslim edilen işlerden hesaplanır. İptal edilen ve geçersiz sayılan fişler toplamlara girmez. Excel dosyasında telefon numarası yoktur."

### 1.7 Excel ve yazdırma (Flutter)

- **Excel'e aktar:** `GET /api/cash/export?period=<key>` (bearer ile, `ResponseType.bytes`) → `getTemporaryDirectory()/kasa-<key>.xlsx` → `Share.shareXFiles`. Dosya adını `content-disposition`'dan alın.
- **Yazdır:** aynı verilerden PDF: başlık "`Firma` · Kasa · `periodTitle`", basım zamanı `formatStamp(now)`, özet kartlar, hizmet/personel tabloları.

---

## 2. Analiz — `/ops/analiz` (`pages/ops/AnalyticsPage.jsx`)

Kabuk: başlık **"Analiz"**, alt "İşin nasıl gittiği: teslim süresi, geri gelen müşteri, puanlar ve yoğun saatler". Aksiyon: dönem radyo segmenti **30 gün** · **90 gün** (varsayılan) · **12 ay** (`range=365`). URL'de `range` (90 ise yok).

- `GET /api/analytics?range=`; **120 sn** otomatik sessiz yenileme.
- `granularity`: `week` (kova `2026-11-02` → "2 Kas" / "2 Kas haftası") ya da `month` (kova `2026-11` → "Kas" / "Kasım 2026").
- Karşılaştırma: 365 ise "önceki 12 aya göre", değilse "önceki `N` güne göre".

Yardımcılar:
- `duration(hours)`: null → "—"; <24 → "`round(h)` saat"; değilse `round(h/24, 1)` "1,5 gün".
- `percentText(v)`: null → "—", değilse "%v".
- `change(now, before)` → before 0 ise null, değilse yuvarlak yüzde.

### 2.1 Özet (6 StatTile)

| Kutu | Değer | Not / delta |
| --- | --- | --- |
| **Ciro** (koyu) | `money(revenue.totalTry)` | delta `change(totalTry, previous.totalTry)` + compare; delta yoksa "Önceki dönemde teslim yok" |
| Teslim edilen iş | `revenue.count` | aynı mantık |
| Zamanında teslim | `percentText(turnaround.onTimeRate)` | "Söz: halı `promiseDays.carpet_wash ?? 4` gün, koltuk `promiseDays.sofa_wash ?? 7` gün" |
| Ortalama teslim süresi | `duration(turnaround.medianHours)` | Fiş açılışından teslime (medyan) |
| Geri gelen müşteri | `percentText(customers.repeatRate)` | "`active` müşteriden `returning` tanesi daha önce de geldi" |
| Ortalama puan | `"4,6 ★"` ya da "—" | "`count` değerlendirme · 5 yıldız %`promoterRate`" |

StatTile delta: ▲ yeşil / ▼ kırmızı / ■ gri, "%12 önceki 90 güne göre".

### 2.2 Grafik çerçevesi (`ChartFrame`)

Her grafik panelinde başlık + ipucu + sağda **[Tablo]/[Grafik]** geçiş düğmesi (aynı veri tablo olarak). Flutter'da `ToggleButtons` veya `TextButton`.

1. **Haftalık/Aylık ciro** (geniş) — sütun grafiği; son sütun vurgulu, lejant "Bu hafta (devam ediyor)" / "Bu ay (devam ediyor)". Y ekseni `niceMax` ile yuvarlak üst sınır, 3 çizgi (max, max/2, 0), etiket `axisNumber` (≥10.000 kısa: "10 B", "2,5 Mn"). İpucu: "Teslim edilen ve geçersiz sayılmayan işler. Üzerine gelince tutar ve teslim sayısı görünür." Tablo: Dönem · Teslim · Ciro.
2. **Teslim süresi** — ipucu "`count` teslim · ortalama `duration(averageHours)`". Yatay çubuk listesi (`BarList`): `buckets[]` label · "`N` iş" · "%x". Altında hizmet listesi: karo · ad · medyan süre · "%`onTimeRate` zamanında" (<80 kırmızı). Tablo: Hizmet · Teslim · Medyan süre · Zamanında.
3. **Puan eğilimi** — ipucu "5 yıldız %p · 1–3 yıldız %d". Çizgi grafik min 1 max 5, tick 1/3/5, "4,5 ★"; değeri olmayan nokta çizgiyi böler. Puan yoksa "Bu dönemde puan gelmedi.". Tablo: Dönem · Puan · Ortalama.

### 2.3 Geciken işler (`id="geciken"`, Todos'tan buraya kaydırılır)

Başlık "Geciken işler" + kırmızı sayı pill. İpucu: "Teslim sözünü aşan açık fişler. Müşteriyi arayıp yeni bir gün verin; en eskisi en üstte." Sağda **"🚚 Servis listesi"** → `/ops/servis`.
Boş: (yeşil) "Geciken iş yok. Bütün açık fişler teslim sözü içinde."
Tablo/kart: Fiş `#REF` · Müşteri (ad + "`27 Kas 2026` açıldı") · Hizmet · Durum (`STATUS_LABELS`) · Gecikme (pill bad "`N` gün") · Tutar · **[Ara]** (`tel:`) **[İş kartı]** (`/ops?q=<REF>`).

Flutter: `ScrollController` + `GlobalKey` ile `#geciken` derin linkinde bu bölüme kaydırın (`Scrollable.ensureVisible`).

### 2.4 Müşteriler ve Yoğun saatler

**Müşteriler** — ipucu "Dönemde `active` müşteri teslim aldı". Mini istatistik: Yeni müşteri · Geri gelen · Müşteri başına ömür boyu (`money`). İki ölçer (`Meter`, 0–100 çubuk, sağda "%x"):
- "En az iki kez gelenlerin oranı" (`repeatRate`) — "Halı yılda bir-iki kez yıkanır; bu oran yükseldikçe reklam gideri düşer."
- "İptal oranı" (`losses.cancelRate`) — "`opened` fişten `cancelled` iptal · `voided` teslimat geçersiz sayıldı"

**Yoğun saatler** — ısı haritası 7 satır (Pzt…Paz) × saat sütunları. Saat aralığı: veri olan saatleri kapsar, en az 08–20. Hücre seviyesi `ceil(LEVELS*count/peak)` (0 → boş). İpucu: en yoğun hücre varsa "En yoğun: `Salı` `10`:00 (`N` fiş). Personeli ve servis aracını buna göre planlayın.", yoksa "Fişlerin açıldığı gün ve saat." Tablo: Gün · Fiş · En yoğun saat ("10:00 (3 fiş)" / "—"). Flutter: yatay kaydırılan `Table`/`GridView`, hücre rengi altın tonları (opaklık seviyesine göre).

### 2.5 Hatırlatma zamanı gelenler

Başlık + sayı pill. İpucu: "Son teslimatı `afterDays` günden eski, mesajları açık müşteriler; en çok bırakan en üstte. WhatsApp düğmesi hazır bir mesajla açılır, göndermeden önce düzenleyebilirsiniz." Boş: "Şimdilik hatırlatılacak müşteri yok."
Satır: Müşteri · Telefon · Son teslim ("27 Kas 2026" + "`N` gün önce") · Sipariş · Toplam · **[WhatsApp'tan hatırlat]** **[Yeni fiş]** (`/ops?fill=<id>`).

Hazır mesaj (`wa.me/<rakamlar>?text=`):
> Merhaba `<ilk ad>`, `<firma adı>` olarak yazıyoruz. Halı ve koltuklarınızın yıkama zamanı geldi; dilerseniz kapınızdan alalım. Uygun gününüzü yazmanız yeterli.

---

## 3. Servis listesi — `/ops/servis` (`pages/ops/RouteSheetPage.jsx`)

Herkese açık. Kabuk: başlık **"Servis listesi"**, alt "Bugün araca binecek işler, adrese göre", aksiyon **"🖨 Yazdır"**.

- `GET /api/route-sheet`; **60 sn** otomatik yenileme.
- Boş (hepsi): "Araca binecek iş yok. Yıkaması biten işler burada görünür."

### 3.1 Gruplar

| key | Başlık | İpucu | Boş metni |
| --- | --- | --- | --- |
| `deliver` | Teslime çıkacak | Yıkaması biten halı, yorgan ve perde. Kapıda tahsil edilecek tutar yanında. | Teslime çıkacak iş yok. |
| `visit` | Koltuk randevuları | Müşterinin evinde yapılacak koltuk yıkama. | Bekleyen koltuk randevusu yok. |
| `pickup` | Kapıdan alınacak | Henüz teslim alınmamış yeni fişler. | (boşsa grup hiç gösterilmez) |

Grup başlığında sayı; adresi olan durak varsa **"Hepsini seç"** (hepsi seçiliyse seçimi kaldırır).

### 3.2 Durak satırı

- Solda onay kutusu (adres yoksa pasif) — "`Ad` rotaya ekle".
- **Ad** · `#REF` · `daysLate > 0` ise pill bad "`N` gün gecikti" (satır vurgulu).
- 📍 adres (dokununca Maps arama) ya da "Adres yok — müşteriyi arayın".
- Meta: hizmet ikonu + adı · "`27 Kas 2026` açıldı" · not varsa "• not".
- Sağda **tutar** (`money` ya da "Fiyat yok") ve 📞 telefon düğmesi.

### 3.3 Rota çubuğu (seçim varsa, yapışkan)

"**`N` durak** · `money(toplam)` tahsilat" (+ `N > 10` ise " · Haritada ilk 10 durak açılır") · **[Seçimi temizle]** · **[📍 Haritada rota aç]**.

Rota linki (Google Maps çok duraklı; başlangıç cihaz konumu):

```dart
String routeHref(List<String> addresses) {
  final stops = addresses.take(10).toList();
  final params = {'api': '1', 'destination': stops.last, 'travelmode': 'driving'};
  if (stops.length > 1) params['waypoints'] = stops.sublist(0, stops.length - 1).join('|');
  return Uri.https('www.google.com', '/maps/dir/', params).toString();
}
```

Liste yenilenince artık listede olmayan işler seçimden düşer. Sayfa sonu: "İşin durumunu **İşler** ekranından ilerletin; teslim edilen iş bu listeden düşer."

---

## 4. Ayarlar — `/ops/ayarlar` (`pages/ops/SettingsPage.jsx`)

Kabuk: başlık **"Ayarlar"**, alt "İşletme bilgileri, WhatsApp ve ekibiniz". Masaüstünde solda form, sağda **önizleme kartı**; altında **Ekip**. Telefonda alt alta.

- `GET /api/settings` → formu doldur (`null` → ""; `alertPhone` → `maskPhone(displayPhone(...))`). Bu değerler "kaydedilmiş taban" olur; form farklıysa `dirty`.

### 4.1 Form bölümleri

**İşletme** (ikon building) — "Müşterilerinizin gördüğü bilgiler"

| Alan | Etiket | Kural |
| --- | --- | --- |
| name | İşletme Adı * | ≤120; ipucu "Müşterilere giden mesajlarda bu ad yazar." `checkBrandName` |
| publicPhone | Müşterinin Göreceği Telefon | `filterPublicPhone`, ≤32, placeholder "0216 123 45 67", odaktan çıkınca `checkPublicPhone` |

**WhatsApp** (chat) — "Mesajların çıktığı hat"

- Anahtar kayıtlı değilse (`!wapioSessionSet`) ya da "Değiştir"e basıldıysa: `PasswordField` **"WhatsApp Bağlantı Anahtarı"**, ≤128, placeholder "Anahtarınızı yapıştırın", ipucu: `platformLine` ise "Boş bırakırsanız mesajlar ortak hattan gider.", değilse "Anahtar girilmeden müşterilere mesaj gitmez." (`checkWapio`)
- Kayıtlıysa durum kutusu: **"Bağlı"** · "Anahtar güvenlik için gizli: `wapioSessionMasked`" · [Değiştir] · [Kaldır] (kırmızı).
- Kaldır onayı: başlık "WhatsApp bağlantısı kaldırılsın mı?", gövde `platformLine` ? "Mesajlar bundan sonra ortak hattan gider." : "Bağlantı kaldırılınca müşterilere mesaj gitmez.", düğme "Bağlantıyı Kaldır" (tehlikeli) → kaydet `{ ...form, wapioSessionClear: true, wapioSessionId: "" }` → "WhatsApp bağlantısı kaldırıldı."

**Puan ve yorumlar** (star) — "Düşük puan size, memnun müşteri Google'a"

| Alan | Etiket | Kural |
| --- | --- | --- |
| alertPhone | Düşük Puan Bildirimi Telefonu | `PhoneField`, isteğe bağlı; ipucu "Müşteri 1–4 yıldız verirse WhatsApp'tan buraya haber gelir. Boşsa işletme sahibine gider." `checkPhone(required:false)` |
| googleReviewUrl | Google Yorum Linki | url klavyesi, ≤500, placeholder "https://g.page/r/…/review"; ipucu "5 yıldız veren müşteri bu sayfaya gider. Boşsa teşekkür ekranında kalır." `checkGoogleUrl` |

**Ödeme** (card) — "Tek dokunuşla gönderilen IBAN bilgisi"

| Alan | Etiket | Kural |
| --- | --- | --- |
| ibanHolder | IBAN Alıcı Adı | ≤120, placeholder "Örn: Yıldız Halı - Ziraat Bankası", `checkLine(…, 120, "IBAN alıcı adı")` |
| ibanNumber | IBAN Numarası | ≤32, placeholder "TR00 0000 0000 0000 0000 0000 00", yazarken `maskIban` (4'lü grup, rakamla başlarsa TR eklenir), odaktan çıkınca `checkIban` (mod-97) |

Alt düğme: `dirty` ise **"Ayarları Kaydet"**, değilse **"Kaydedildi"** (pasif); gönderirken "Kaydediliyor…".

### 4.2 Kaydetme

```text
check = runChecks(name: checkBrandName, publicPhone: checkPublicPhone, alertPhone: checkPhone(required:false),
                  googleReviewUrl: checkGoogleUrl, wapioSessionId: checkWapio, ibanHolder: checkLine, ibanNumber: checkIban)
PUT /api/settings { ...form, name, publicPhone ?? "", alertPhone (E.164) ?? "", googleReviewUrl ?? "",
                    wapioSessionId ?? "", ibanHolder ?? "", ibanNumber (gruplu) ?? "", ...extra }
→ "Ayarlar kaydedildi." → settings.reload(silent) + session.refresh()   // kabuktaki firma adı/WhatsApp durumu değişir
```
Alan eşlemesi: `{ business: "name" }` + `settings_*` kodları (02-api §4).

### 4.3 Önizleme kartı — "Müşteriniz böyle görür"

Telefon taklidi: üstte baş harf dairesi + işletme adı (boşsa "İşletme"); WhatsApp balonu:
> **`İŞLETME ADI` (tr büyük harf)**
> Merhaba Ayşe Hanım, ürünleriniz özenle temizlenmek üzere teslim alındı.
> Fiş No: #HK1001
> Bizi tercih ettiğiniz için teşekkür ederiz.
> `10:24 ✓✓`

Altında özet:
- Düşük puan bildirimi: `alertPhone` ya da "Sizin telefonunuza gelir"
- Google yorum sayfası: dolu ise "Eklendi", değilse "Link yok, müşteri teşekkür ekranında kalır"
- WhatsApp: anahtar kayıtlı ya da yazılmış ya da `platformLine` → "Bağlı", değilse "Bağlı değil"
- IBAN: `ibanNumber` ya da "Kayıtlı IBAN yok"

### 4.4 Ekip (`Team`)

Başlık **"Ekibiniz"**, ipucu "Personel yalnız işleri, müşterileri ve yorumları görür. Kasa ve ayarlar yöneticiye açıktır." Sağda **[Kişi Ekle]**.

- `GET /api/team`. Tablo: Ad · Telefon · Yetki (`ROLE_LABELS`) · Durum (pill ok "Aktif" / muted "Pasif") · işlemler:
  - `canToggle` → **"Pasif yap"** / **"Aktif et"** → `POST /team/:id/toggle` → "Kişinin durumu güncellendi."
  - `canResetPassword` → **"Şifre sıfırla"** → `PasswordDialog`
  - `canDelete && me.role == super_admin` → **"Sil"** (uygulamada super_admin olmadığı için gösterilmez)
- Boş: "Henüz personel yok."

**Kişi ekle formu** ("Yeni kişi"): Ad Soyad * (≤120) · Cep Telefonu * · Şifre * (güç, ipucu "En az 8 karakter; en az bir harf ve bir rakam.") · Şifre (tekrar) * · **Yetki** açılır liste: "Personel (yalnız işler)" (`staff`, varsayılan) / "Yönetici (tam yetki)" (`admin`). [Kişiyi Ekle] [Vazgeç].
- `POST /api/team { name, phone (E.164), password, role }` → "Kişi eklendi." → form sıfırla, kapat, listeyi yenile.

**PasswordDialog** (şifre sıfırla): başlık "`Ad` için yeni şifre", gövde "Personel bir sonraki girişte bu şifreyi kullanır. Açık oturumları kapanır.", Yeni şifre (güç) · Yeni şifre (tekrar), [Vazgeç] [Şifreyi Sıfırla]. `checkNewPassword(password, member.phone)`. `POST /team/:id/password { password }` → "`Ad` için yeni şifre kaydedildi."; hata pencerede şifre alanının altına.

**Sil onayı** (web, super_admin): "`Ad` hesabı silinsin mi?" · "Bu işlem geri alınamaz. Olacaklar:" · "`0532…` ile giriş kapanır." · "Açık oturumları düşer." · "Açtığı fişler silinmez." · "SİL" yazmadan açılmaz.

### 4.5 🆕 Hesabı sil (Flutter'a özel; mağaza zorunluluğu)

Yalnız `me.user.isOwner == true` ise Ayarlar'ın en altında kırmızı bölüm **"İşletme hesabını sil"**:
- Açıklama: "Firma hemen kapanır, bütün hesapların oturumları kapanır, gönderilmemiş mesajlar iptal edilir. 30 gün içinde giriş ekranından geri alabilirsiniz; süre dolunca bütün kayıtlar kalıcı olarak silinir."
- Onay penceresi: şifre alanı + "SİL" yazma → `POST /api/account/deletion { password }` → `deletionDueAt` → çıkış yap → giriş ekranında bilgi: "Hesabınız `formatDay(deletionDueAt)` tarihinde silinecek."
- Hatalar: `wrong_password` (`field: password`), `owner_only`.
