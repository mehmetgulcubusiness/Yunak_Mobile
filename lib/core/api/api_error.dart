/// API hata cevabı: `{ error: { code, message, field?, ...details } }`.
/// `status == 0` ağ hatasıdır.
class ApiError implements Exception {
  ApiError(this.status, this.code, this.message, [Map<String, dynamic>? extra])
      : extra = extra ?? const {},
        field = (extra?['field'] is String) ? extra!['field'] as String : null;

  final int status;
  final String code;
  final String message;
  final String? field;
  final Map<String, dynamic> extra;

  static ApiError network() => ApiError(0, 'network', 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.');

  bool get isNetwork => status == 0;
  bool get isTenantBlock => status == 403 && code.startsWith('tenant_');

  @override
  String toString() => 'ApiError($status, $code, $message)';
}
