import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/labels.dart';
import '../../core/format/format.dart';
import '../widgets/common.dart';

class SlipData {
  const SlipData({
    required this.businessName,
    this.businessPhone,
    required this.reference,
    this.createdAt,
    required this.customerName,
    required this.phone,
    this.address,
    required this.serviceType,
    this.deskNote,
    this.amount,
  });
  final String businessName;
  final String? businessPhone;
  final String reference;
  final String? createdAt;
  final String customerName;
  final String phone;
  final String? address;
  final String serviceType;
  final String? deskNote;
  final num? amount;
}

pw.Font? _regular;
pw.Font? _bold;

Future<void> _fonts() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
}

/// Müşteri fişi: 80 mm rulo (yazdırma penceresinden A4 de seçilebilir).
Future<void> printSlip(SlipData d) async {
  try {
    await _fonts();
    await Printing.layoutPdf(
      name: 'Fiş ${d.reference}',
      format: PdfPageFormat.roll80,
      onLayout: (format) async {
        final doc = pw.Document(theme: pw.ThemeData.withFont(base: _regular, bold: _bold));
        final small = pw.TextStyle(fontSize: format.width > 300 ? 11 : 9);
        pw.Widget rule() => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Divider(thickness: .6));
        doc.addPage(pw.Page(
          pageFormat: format.copyWith(marginLeft: 12, marginRight: 12, marginTop: 12, marginBottom: 12),
          build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(d.businessName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            if ((d.businessPhone ?? '').isNotEmpty) pw.Text(d.businessPhone!, style: small),
            rule(),
            pw.Text('Fiş No: ${d.reference}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (d.createdAt != null) pw.Text(formatStamp(d.createdAt), style: small),
            rule(),
            pw.Text(d.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(displayPhone(d.phone), style: small),
            if ((d.address ?? '').trim().isNotEmpty) pw.Text(d.address!.trim(), style: small),
            rule(),
            pw.Text(serviceOf(d.serviceType).title),
            if ((d.deskNote ?? '').trim().isNotEmpty) pw.Text(d.deskNote!.trim(), style: small),
            if (d.amount != null) pw.Text('Tutar: ${money(d.amount)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            rule(),
            pw.Text('Bizi tercih ettiğiniz için teşekkür ederiz.', style: small),
          ]),
        ));
        return doc.save();
      },
    );
  } catch (_) {
    toast('Fiş yazdırılamadı.', tone: ToastTone.bad);
  }
}
