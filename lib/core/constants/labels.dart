// Arayüz metinleri. Sunucu ham değer döner (status, serviceType, role…); Türkçe karşılıkları buradadır.

const statusLabels = {
  'draft': 'Yeni',
  'received': 'Teslim alındı',
  'washing': 'Yıkamada',
  'delivered': 'Teslim edildi',
  'cancelled': 'İptal',
  'scheduled': 'Randevulu',
  'in_progress': 'İşlemde',
  'completed': 'Bitti',
};

const moveLabels = {
  'received': 'Teslim alındı',
  'washing': 'Yıkamada',
  'delivered': 'Teslim edildi',
  'scheduled': 'Randevu Ver',
  'in_progress': 'Hemen Başla',
  'completed': 'İşi Bitir',
};

class Service {
  const Service(this.value, this.title, this.short, this.icon, this.pick, this.unit);
  final String value;
  final String title;
  final String short;
  final String icon;
  final String pick;

  /// Fiyatın neye göre hesaplandığı: halı ve perde m², koltuk ve yorgan adet.
  final String unit;
}

const services = [
  Service('carpet_wash', 'Halı Yıkama', 'Halı', 'carpet', 'Halı', 'm²'),
  Service('sofa_wash', 'Koltuk Yıkama', 'Koltuk', 'sofa', 'Koltuk', 'Adet'),
  Service('quilt_wash', 'Yorgan / Battaniye', 'Yorgan', 'quilt', 'Yorgan', 'Adet'),
  Service('curtain_wash', 'Perde / Stor', 'Perde', 'curtain', 'Perde', 'm²'),
];

Service serviceOf(String? v) => services.firstWhere((s) => s.value == v, orElse: () => services.first);

const roleLabels = {'super_admin': 'Platform Yöneticisi', 'admin': 'Yönetici', 'staff': 'Personel'};

const businessStatusLabels = {'pending': 'Onay Bekliyor', 'active': 'Aktif', 'suspended': 'Askıda', 'rejected': 'Reddedildi'};

const feedbackReasons = <(String, String)>[
  ('stain_remains', 'Leke çıkmadı'),
  ('odor', 'Koku var'),
  ('delivery_delay', 'Teslimat gecikti'),
  ('damage', 'Hasar veya deformasyon'),
  ('staff', 'Personel'),
  ('wetness_or_residue', 'Islaklık veya kalıntı'),
  ('other', 'Başka bir sorun'),
];

String reasonLabel(String code) => feedbackReasons.firstWhere((r) => r.$1 == code, orElse: () => (code, code)).$2;

const starCaptions = {1: 'Çok Kötü', 2: 'Kötü', 3: 'Orta', 4: 'İyi', 5: 'Mükemmel'};

/// "★ Yıldız İste" atlandığında gösterilen neden.
const skipReasonLabels = {
  'not_success_terminal': 'İş henüz bitmedi.',
  'customer_opted_out': 'Müşteri mesajları kapattı.',
  'already_submitted': 'Müşteri zaten puan verdi.',
  'invitation_closed': 'Bu iş için puan isteği kapandı.',
  'already_opened': 'Müşteri linki açtı. Süresi dolmadan yeniden gönderilmez.',
  'already_sent': 'Puan linki zaten gönderildi.',
  'resend_limit': 'Tek yeniden gönderim hakkı kullanıldı.',
  'expired_needs_manual': 'Linkin süresi doldu.',
  'missing_anchor': 'İşin bitiş zamanı yok.',
  'covered_by_batch': 'Bu müşteriye aynı gün başka bir iş için link gitti.',
  'cooldown': 'Bu müşteriye son 7 günde puan linki gönderildi.',
  'order_voided': 'Teslimat geçersiz sayıldı.',
};

/// Müşteri kartındaki etiket; sayılan (iptal ve geçersiz hariç) sipariş sayısına göre.
({String label, bool gold}) loyaltyOf(int orderCount) {
  if (orderCount >= 5) return (label: '★ Sadık müşteri', gold: true);
  if (orderCount >= 2) return (label: 'Tekrar gelen', gold: false);
  return (label: 'Yeni müşteri', gold: false);
}
