/// Sunucu JSON'unu güvenle okumak için küçük yardımcılar. Beklenmeyen tip
/// ya da eksik alan ekranı çökertmez; varsayılan değer döner.
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Json> asJsonList(Object? v) => v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : <Json>[];

extension JsonRead on Json {
  String? s(String k) {
    final v = this[k];
    if (v == null) return null;
    return v is String ? v : '$v';
  }

  String str(String k, [String fallback = '']) => s(k) ?? fallback;

  num? n(String k) {
    final v = this[k];
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  int i(String k, [int fallback = 0]) => n(k)?.toInt() ?? fallback;
  int? iOrNull(String k) => n(k)?.toInt();
  double? d(String k) => n(k)?.toDouble();
  bool b(String k) => this[k] == true;
  Json m(String k) => asJson(this[k]);
  Json? mOrNull(String k) => this[k] is Map ? asJson(this[k]) : null;
  List<Json> l(String k) => asJsonList(this[k]);
  List<String> strings(String k) => this[k] is List ? (this[k] as List).map((e) => '$e').toList() : <String>[];
  List<num> nums(String k) => this[k] is List ? (this[k] as List).map((e) => e is num ? e : num.tryParse('$e') ?? 0).toList() : <num>[];
}
