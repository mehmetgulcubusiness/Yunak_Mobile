# 02 — API uçları

Kaynak: `ccs_client/src/api/endpoints.js` (client'ın kullandığı) + `ccs_server/src/routes/index.ts` + `ccs_server/docs/openapi.yaml` (asıl sözleşme). Alan listeleri, client'ın gerçekten okuduğu alanlardır; tam şema için `openapi.yaml`.

- Kök: `https://<alan-adı>` (web ile aynı sunucu). Dev: `http://10.0.2.2:8080` (Android emülatör) / `http://127.0.0.1:8080` (iOS sim). `--dart-define=API_BASE_URL=…`.
- Bütün zamanlar ISO-8601 UTC string; gösterirken Europe/Istanbul'a çevrilir.
- Telefonlar sunucudan **E.164** gelir (`+905321110031`), gösterimde `0532 111 00 31`.
- Tutarlar sunucudan **sayı** (`1250.5`) gelir; sunucuya **string** `"1250,5"` gider (`amountWire`, bkz. 10-dogrulama).
- Sayfalama: `page` 1'den başlar, sayfa boyu **50**. Cevapta `total` ve `page` (sunucunun gerçekten döndüğü sayfa).
- Kimlikler yol parametresinde her zaman URL-encode.

İşaretler: 🔓 oturumsuz · 👤 oturum · 🏢 oturum + firma · 👑 yönetici (admin/super_admin) · 🛡 super_admin · 📱 yalnız uygulama · 🆕 web client'ta yok, Flutter'da eklenecek

---

## 1. Kimlik ve oturum

| Metot | Yol | Yetki | Gövde | Cevap |
| --- | --- | --- | --- | --- |
| GET | `/api/mobile/config` | 🔓📱 | — | `{ minVersion, latestVersion?, updateUrl?, accessTtlSeconds }` |
| POST | `/api/mobile/auth/login` | 🔓📱 | `{ phone, password, deviceName? }` (deviceName ≤ 60) | `{ accessToken, accessExpiresAt, refreshToken, sessionExpiresAt, me: Me }` |
| POST | `/api/mobile/auth/refresh` | 🔓📱 | `{ refreshToken }` | `{ accessToken, accessExpiresAt, refreshToken, sessionExpiresAt }` |
| POST | `/api/mobile/auth/logout` | 👤📱 (bearer) | — | 204 |
| GET | `/api/auth/me` | 👤 | — | `Me` |
| POST | `/api/auth/register` | 🔓 | `{ business, name, phone, password }` | başvuru alındı (firma `pending`) |
| POST | `/api/auth/password` | 👤 | `{ currentPassword, newPassword }` | 204/200; diğer oturumlar kapanır |
| POST | `/api/auth/logout-all` | 👤 | — | tüm cihazlardan çık 🆕 |
| GET | `/api/auth/sessions` | 👤 | — | `{ items: SessionView[] }` 🆕 Cihazlarım |
| DELETE | `/api/auth/sessions/:id` | 👤 | — | 204 🆕 |
| POST | `/api/account/deletion` | 🏢 (yalnız sahip) | `{ password }` | `{ deletionDueAt }` 🆕 |
| POST | `/api/account/deletion/cancel` | 🔓 | `{ phone, password }` | 204 🆕 |
| GET | `/api/health` | 🔓 | — | `{ ok, version? }` |

> Web'de giriş `POST /api/auth/login` (çerez). **Uygulama bunu kullanmaz**, `/api/mobile/auth/login` kullanır. Web logout `/api/auth/logout`, uygulama `/api/mobile/auth/logout`.

> ⚠️ `register`, `account/deletion/cancel` ve puan sayfası POST'ları oturumsuzdur; bu yüzden sunucunun CSRF origin korumasına takılır (üretimde Origin başlığı zorunlu, bkz. [11-yol-haritasi.md](11-yol-haritasi.md#3-sunucu-tarafında-gereken-değişiklikler)).

### `Me`

```jsonc
{
  "user":   { "id": "…", "name": "Ayşe Yılmaz", "role": "admin|staff|super_admin", "phone": "+905…", "isOwner": true },
  "tenant": {                       // firma yoksa null (yalnız super_admin; uygulamada olmaz)
    "id": "…", "name": "Yıldız Halı", "phone": "0216 …", "status": "active",
    "whatsappBound": true,
    "setup": { "googleReview": true, "iban": false }   // İşler › "Kurulumu tamamlayın (x/3)"
  },
  "supporting": false, "supportExpiresAt": null,       // destek modu (web-only)
  "openCrises": 2                                      // bekleyen düşük puan
}
```

### `SessionView` (Cihazlarım)

`{ id, kind: "web"|"device", platform: "android"|"ios"|null, deviceName, clientVersion, createdAt, lastSeenAt, current }`

---

## 2. İşletme verisi

### 2.1 Gösterge — `GET /api/dashboard` 🏢

Kabuk bir kez yükler; sayfalar her işlemden sonra yeniden çağırır (`reloadDashboard`).

```jsonc
{
  "kpis":  { "activeOrders": 8, "washingOrders": 4, "deliveredToday": 3, "revenueToday": 5600, "deliveryRate": 92 }, // revenueToday personele null
  "tabs":  { "open": 8, "waiting": 3, "collected": 2, "washing": 4, "delivered": 12, "archive": 340 },
  "queue": { "pending": 0, "claimed": 0, "uncertain": 0, "failed": 1, "sent": 120, "lastError": "…" },
  "openCrises": 2,
  "overdue": 1
}
```

### 2.2 Fişler (siparişler)

| Metot | Yol | Yetki | Gövde / query | Cevap |
| --- | --- | --- | --- | --- |
| GET | `/api/orders` | 🏢 | `tab` (`open`\|`waiting`\|`collected`\|`washing`\|`delivered`\|`archive`), `q` (≤80), `page`, `month` (`YYYY-MM`, arşiv) | `{ items: DeskOrder[], total, page, days?, months? }` |
| GET | `/api/orders/suggested-reference` | 🏢 | — | `{ reference: "HK1043" }` |
| POST | `/api/orders` | 🏢 | `{ service, name, phone, reference, amount, address, note, allowDuplicate? }` | `OpenOrderResult` |
| POST | `/api/orders/:id/advance` | 🏢 | `{ to }` | `{ status, replay }` |
| POST | `/api/orders/:id/cancel` | 🏢 | — | `{ status, replay }` |
| POST | `/api/orders/:id/void` | 🏢👑 | — | `{ … }` |
| POST | `/api/orders/:id/rating-request` | 🏢 | — | `{ outcome: "queued"\|"skipped", reason? }` |
| POST | `/api/orders/:id/retry` | 🏢 | — | `{ requeued: number }` |
| PATCH | `/api/orders/:id/quote` | 🏢 (biten işte 👑) | `{ amount, note }` | — |
| POST | `/api/orders/:id/send-iban` | 🏢 | — | `{ queued: true }` |
| POST | `/api/outbox/flush` | 🏢 | — | bekleyen mesajları gönder |

`DeskOrder`:

```jsonc
{
  "id": "uuid", "customerId": "uuid", "reference": "HK1001",
  "serviceType": "carpet_wash|sofa_wash|quilt_wash|curtain_wash",
  "customerName": "Ayşe Yılmaz", "phone": "+905…", "address": "…|null", "deskNote": "…|null",
  "status": "draft|received|washing|delivered|cancelled|scheduled|in_progress|completed",
  "voided": false,
  "createdAt": "…", "dueAt": "…", "deliveredAt": "…|null",
  "amount": 1250.5,            // null = fiyat girilmedi
  "actorName": "Mehmet|null",  // fişi açan
  "feedback": { "stars": 2, "note": "…" } ,   // düşük puan varsa, yoksa null
  "whatsappSent": true, "whatsappStuck": false,
  "moves": [{ "to": "washing" }, { "to": "delivered" }],  // izinli sonraki durumlar (sunucu belirler)
  "cancellable": true, "voidable": false,
  "previewToken": null          // yalnız geliştirme sunucusunda dolu → "(Test)" linki
}
```

`days` (teslim edilen sekmeler): `[{ day: "2026-11-27", count: 5, totalTry: 4200 | null }]` — `totalTry` yalnız yöneticiye dolu.
`months` (arşiv): `[{ month: "2026-11", count: 40 }]`.

`OpenOrderResult`: `{ orderId, reference, replay, messagesSuppressed, existingCustomer: { name } | null }`
- `reference` gönderilenden farklıysa: "`X` doluydu, `Y` verildi."

Durum makinesi (sunucu `moves` ile verir, istemci yalnız gösterir):

```text
Halı / Yorgan / Perde:  received ──► washing ──► delivered
                        received ─────────────► delivered   ("Yıkamadan Teslim Et")
Koltuk:                 draft ──► scheduled ──► in_progress ──► completed
Her açık iş:            ──► cancelled (cancellable=true ise)
Biten iş:               void (voidable=true, yönetici) → durum değişmez, voided=true
```

### 2.3 Müşteriler

| Metot | Yol | Yetki | Gövde / query | Cevap |
| --- | --- | --- | --- | --- |
| GET | `/api/customers` | 🏢 | `q`, `page` | `{ items: CustomerRow[], total, page }` |
| GET | `/api/customers/:id` | 🏢 | — | `CustomerCard` |
| PUT | `/api/customers/:id` | 🏢 | `{ name, phone, address }` | güncel kart (dönmezse eski kart korunur) |
| PUT | `/api/customers/:id/note` | 🏢 | `{ note }` (≤500, boş = sil) | güncel kart veya boş |
| POST | `/api/customers/:id/opt-out` | 🏢 | — | mesajlar kapandı |
| POST | `/api/customers/:id/opt-in` | 🏢 | — | mesajlar açıldı |
| DELETE | `/api/customers/:id` | 🏢👑 | — | KVKK silme |
| POST | `/api/customers/:id/send-iban` | 🏢 | — | IBAN mesajı |

`CustomerRow`: `{ id, name, phone, address|null, optedOut, orderCount, totalTry, lastOrderAt|null }`

`CustomerCard`: `{ id, name, phone, registeredAt, address, note, optedOut, orderCount, totalTry, lastStars|null, orders: [{ id, reference, serviceType, createdAt, amount, status, voided, note, actorName }] }`

### 2.4 Yorumlar (puanlar)

| Metot | Yol | Yetki | Query | Cevap |
| --- | --- | --- | --- | --- |
| GET | `/api/ratings` | 🏢 | `filter` (`unresolved`\|`shield`\|`google`\|`resolved`; "Tümü" için gönderme), `q`, `page` | `{ items: RatingRow[], total, page, summary }` |
| POST | `/api/ratings/:id/resolve` | 🏢 | — | çözüldü |

`RatingRow`: `{ id, customerName, phone, reference, serviceType, stars, route: "google"|"shield", resolved, submittedAt, reasons: FeedbackReason[], note }`
`summary`: `{ total, average, starCounts: [n1, n2, n3, n4, n5], openCrises, shieldCount, googleCount, resolvedCount }`

### 2.5 Kasa — 👑

| Metot | Yol | Query | Cevap |
| --- | --- | --- | --- |
| GET | `/api/cash` | `period`: `today` \| `week` \| (boş = bu ay) \| `YYYY-MM` | aşağıda |
| GET | `/api/cash/export` | `period` (aynı) | Excel dosyası (binary); telefon numarası içermez |

```jsonc
{
  "period":  { "key": "month|today|week|2026-10", "start": "…" },
  "summary": { "totalTry": 0, "count": 0, "averageTry": 0, "unpriced": 0, "cancelled": 0,
               "voided": { "count": 0, "totalTry": 0 }, "previous": { "totalTry": 0, "count": 0 } },
  "chart":   [{ "day": "2026-11-01", "totalTry": 0, "count": 0, "future": false }],
  "periodServices": [{ "serviceType": "carpet_wash", "count": 0, "totalTry": 0, "averageTry": 0 }],
  "periodStaff":    [{ "name": "Mehmet|null", "opened": 0, "delivered": 0, "deliveredTry": 0 }],
  "topCustomers":   [{ "id": "…", "name": "…", "count": 0, "totalTry": 0 }],
  "inside": { "totalTry": 0, "count": 0, "unpriced": 0, "oldestDays": 3,
              "stages": [{ "stage": "collected|washing|booked", "count": 0, "totalTry": 0 }] },
  "months": [{ "month": "2026-10", "count": 40 }]
}
```

### 2.6 Analiz ve Servis listesi

| Metot | Yol | Yetki | Query | Cevap |
| --- | --- | --- | --- | --- |
| GET | `/api/analytics` | 🏢👑 | `range`: `30` \| `90` \| `365` | aşağıda |
| GET | `/api/route-sheet` | 🏢 | — | `{ deliver: RouteStop[], visit: RouteStop[], pickup: RouteStop[] }` |

`RouteStop`: `{ id, reference, customerId, customerName, phone, address|null, serviceType, status, createdAt, amount|null, note|null, daysLate }`

Analiz cevabı:

```jsonc
{
  "range":   { "granularity": "week|month" },
  "revenue": { "totalTry": 0, "count": 0, "previous": { "totalTry": 0, "count": 0 },
               "series": [{ "bucket": "2026-11-02|2026-11", "totalTry": 0, "count": 0 }] },
  "turnaround": { "onTimeRate": 92, "medianHours": 60, "averageHours": 70, "count": 0,
                  "promiseDays": { "carpet_wash": 4, "sofa_wash": 7 },
                  "buckets": [{ "key": "…", "label": "1 gün içinde", "count": 0 }],
                  "byService": [{ "serviceType": "…", "count": 0, "medianHours": 0, "onTimeRate": 0 }] },
  "customers": { "active": 0, "returning": 0, "newCustomers": 0, "repeatRate": 0, "averageLifetimeTry": 0 },
  "ratings":   { "average": 4.6, "count": 0, "promoterRate": 0, "detractorRate": 0,
                 "series": [{ "bucket": "…", "count": 0, "average": 4.5 }] },
  "losses":    { "opened": 0, "cancelled": 0, "voided": 0, "cancelRate": 0 },
  "overdue":   { "count": 0, "items": [{ "id", "reference", "customerName", "phone", "serviceType", "status", "createdAt", "daysLate", "amount" }] },
  "reactivation": { "count": 0, "afterDays": 180,
                    "items": [{ "id", "name", "phone", "lastOrderAt", "daysSince", "orderCount", "totalTry" }] },
  "intake": { "grid": [[0, …24 saat], …7 gün (Pzt..Paz)] }
}
```

### 2.7 Ayarlar ve ekip — 👑

| Metot | Yol | Gövde | Cevap |
| --- | --- | --- | --- |
| GET | `/api/settings` | — | `Settings` |
| PUT | `/api/settings` | `SettingsUpdate` | — |
| GET | `/api/team` | — | `{ items: TeamMember[] }` |
| POST | `/api/team` | `{ name, phone, password, role: "staff"\|"admin" }` | — |
| POST | `/api/team/:id/toggle` | — | aktif/pasif |
| POST | `/api/team/:id/password` | `{ password }` | şifre sıfırla |
| DELETE | `/api/team/:id` | — | 🛡 yalnız super_admin (uygulamada gösterilmez) |

`Settings`: `{ name, publicPhone, alertPhone, googleReviewUrl, wapioSessionId: "", wapioSessionMasked: "a06b…6c", wapioSessionSet, ibanHolder, ibanNumber, platformLine }`
`SettingsUpdate`: `{ name, publicPhone, alertPhone, googleReviewUrl, wapioSessionId (boş = mevcut korunur), wapioSessionClear?: true, ibanHolder, ibanNumber }`
`TeamMember`: `{ id, name, phone, role, active, owner, canToggle, canDelete, canResetPassword }`

### 2.8 Platform (genel admin) — 🛡 web-only

`GET /api/platform/businesses?status=pending|active|suspended|rejected|` → `{ items: PlatformBusiness[], counts: { pending, active, suspended, rejected } }`
`POST /api/platform/businesses` `{ business, name, phone, password }` · `POST …/:id/approve` · `…/:id/reject {note}` · `…/:id/suspend {note}` · `…/:id/activate` · `POST /api/platform/switch {businessId}`.
Flutter'da yazılmaz (bkz. 08).

### 2.9 Müşteri puan sayfası — 🔓 (web'de kalır)

`GET /api/public/ratings/:token` · `POST …/:token/stars { token, stars }` · `POST …/:token/reasons { token, reasons, note }` → `PublicRatingView` (`state`: `absent|expired|stars|reasons|thanks|recorded|received`). 404 → absent, 410 → expired, 429 → limited.

---

## 3. Hata kodları (client'ın özel davrandıkları)

Tam liste: `ccs_server/docs/ERROR_CODES.md`.

| HTTP | code | İstemci davranışı |
| --- | --- | --- |
| 0 | `network` | Bağlantı şeridi; form korunur |
| 401 | `unauthenticated` | Bir kez refresh → olmazsa login (`expired`) |
| 401 | `invalid_credentials` | Giriş: formun üstünde mesaj. Şifre değiştir: `currentPassword` alanına |
| 401 | `refresh_reused` | Tokenları sil → login |
| 403 | `tenant_pending` / `tenant_rejected` / `tenant_suspended` / `tenant_closing` | BlockedPage |
| 403 | `platform_admin_web_only` | Giriş ekranında mesaj |
| 403 | `forbidden_role` | Toast |
| 409 | `reference_taken` | Fiş no alanı kırmızı; `extra.suggested` ile "`X` numarasını kullan" düğmesi; yoksa yeni öneri çek |
| 409 | `duplicate_today` | Onay penceresi: "Bu müşteriye bugün fiş açıldı" → evet ise `allowDuplicate: true` ile tekrar gönder. `extra.reference` |
| 409 | `illegal_transition`, `not_cancellable`, `not_voidable`, `invalid_status` | Başkası değiştirmiş: toast + listeyi yenile |
| 426 | `client_outdated` | Zorunlu güncelleme (`minVersion`, `updateUrl`) |
| 429 | `rate_limited` | Giriş: düğmede geri sayım (`retryAfterSeconds`, yoksa 60) "Bekleyin (N sn)" |
| 404 | (password ucu) | "Sunucu şifre değiştirmeyi henüz desteklemiyor." |

## 4. Hata kodu → form alanı eşlemesi

`fieldOfError(error, overrides)`: önce `overrides[code]`, sonra sunucunun `field`'ı (varsa `overrides[field]` ile çevrilir), sonra aşağıdaki tablo.

| code | alan |
| --- | --- |
| `invalid_phone`, `phone_taken` | `phone` |
| `invalid_name` | `name` |
| `invalid_reference`, `reference_taken` | `reference` |
| `invalid_amount` | `amount` |
| `invalid_password`, `weak_password`, `password_is_phone`, `invalid_credentials` | `password` |
| `invalid_business_name` | `business` |
| `address_too_long` | `address` |
| `note_too_long` | `note` |
| `settings_iban` | `ibanNumber` |
| `settings_public` | `publicPhone` |
| `settings_url` | `googleReviewUrl` |
| `settings_session` | `wapioSessionId` |
| `settings_alert` | `alertPhone` |

Sayfa bazlı `overrides`:
- Şifre değiştir: `{ invalid_credentials: "currentPassword", password_unchanged: "newPassword" }` (ayrıca `wrong_password` sunucudan `field: currentPassword` gelir).
- Ayarlar: `{ business: "name" }`.

## 5. Dart istemci iskeleti

```dart
class OrdersApi {
  OrdersApi(this._c);
  final ApiClient _c;

  Future<OrderPage> list({String tab = 'open', String q = '', int page = 1, String? month}) =>
      _c.get('/api/orders', query: {'tab': tab, 'q': q, 'page': page, 'month': month}).then(OrderPage.fromJson);
  Future<String?> suggestedReference() =>
      _c.get('/api/orders/suggested-reference').then((j) => j?['reference'] as String?);
  Future<OpenOrderResult> open(OpenOrderBody body) => _c.post('/api/orders', body.toJson()).then(OpenOrderResult.fromJson);
  Future<void> advance(String id, String to) => _c.post('/api/orders/${seg(id)}/advance', {'to': to});
  Future<void> cancel(String id) => _c.post('/api/orders/${seg(id)}/cancel', {});
  Future<void> voidOrder(String id) => _c.post('/api/orders/${seg(id)}/void', {});
  Future<RatingRequestResult> requestRating(String id) => _c.post('/api/orders/${seg(id)}/rating-request', {}).then(RatingRequestResult.fromJson);
  Future<int> retry(String id) => _c.post('/api/orders/${seg(id)}/retry', {}).then((j) => (j?['requeued'] as num?)?.toInt() ?? 0);
  Future<void> quote(String id, {required String amount, required String note}) =>
      _c.patch('/api/orders/${seg(id)}/quote', {'amount': amount, 'note': note});
  Future<void> sendIban(String id) => _c.post('/api/orders/${seg(id)}/send-iban', {});
  Future<void> flush() => _c.post('/api/outbox/flush', {});
}

String seg(Object? v) => Uri.encodeComponent('${v ?? ''}');
```

`ApiClient.get(path, query:)` boş/null query değerlerini atmalı (web'deki `query()` gibi). POST'larda gövde yoksa `{}` gönderilir (web `http.post(path, body = {})`).
