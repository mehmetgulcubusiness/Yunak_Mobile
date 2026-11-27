import 'package:url_launcher/url_launcher.dart';

import '../../core/format/format.dart';
import 'common.dart';

Future<void> openExternal(String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) toast('Bağlantı açılamadı.', tone: ToastTone.bad);
}

Future<void> callPhone(String? e164) => openExternal(telHref(e164));
Future<void> openWhatsapp(String? e164, [String? text]) => openExternal(waHref(e164, text));
Future<void> openMaps(String address) => openExternal(mapsHref(address));
