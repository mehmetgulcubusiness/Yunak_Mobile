import 'package:flutter/material.dart';

/// Tasarım dili: sessiz lüks. Monokrom yüzeyler, tek vurgu (mat şampanya altını),
/// tek ana aksiyon rengi (mat siyah). Yeşil ve kırmızı yalnız durum bildirir.
/// Kaynak: ccs_client/src/styles/base.css
abstract final class C {
  static const canvas = Color(0xFFF4F4F6);
  static const chip = Color(0xFFF4F4F5);
  static const surface = Color(0xFFFFFFFF);
  static const sunk = Color(0xFFFAFAFA);
  static const line = Color(0xFFE4E4E7);
  static const lineSoft = Color(0xFFF4F4F5);
  static const lineStrong = Color(0xFFD4D4D8);
  static const stone = Color(0xFFA1A1AA);

  static const ink = Color(0xFF09090B);
  static const inkSoft = Color(0xFF52525B);
  static const muted = Color(0xFF71717A);

  static const side = Color(0xFF09090B);
  static const side2 = Color(0xFF18181B);
  static const sideInk = Color(0xFFA1A1AA);

  static const action = Color(0xFF18181B);
  static const actionHover = Color(0xFF27272A);
  static const gold = Color(0xFFC5A059);
  static const goldHover = Color(0xFFB08D48);
  static const goldInk = Color(0xFF1C1608);

  static const ok = Color(0xFF166534);
  static const okBg = Color(0xFFEDF5EF);
  static const warn = Color(0xFF7A5A1E);
  static const warnBg = Color(0xFFF7F1E4);
  static const bad = Color(0xFF9F2A20);
  static const badBg = Color(0xFFF8EBE9);

  static const midBg = Color(0xFFFEF3C7);
  static const midInk = Color(0xFF92400E);
  static const midBar = Color(0xFF10B981);
  static const undoBg = Color(0xFFFFFBEB);
}

abstract final class Shadows {
  static const card = [BoxShadow(color: Color(0x0D09090B), blurRadius: 20, offset: Offset(0, 4), spreadRadius: -2)];
  static const lift = [BoxShadow(color: Color(0x1A09090B), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -4)];
  static const lg = [BoxShadow(color: Color(0x4D000000), blurRadius: 56, offset: Offset(0, 24), spreadRadius: -20)];
  static const darkKpi = [BoxShadow(color: Color(0x8C09090B), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -12)];
}

/// Ekran genişliği kırılımları (ops.css).
abstract final class Bp {
  static const wide = 900.0;
  static const phone = 640.0;
}

const tabular = [FontFeature.tabularFigures()];
