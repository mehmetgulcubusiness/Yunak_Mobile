import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/router.dart';
import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'ui/auth/status_pages.dart';
import 'ui/widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  try {
    final info = await PackageInfo.fromPlatform();
    if (RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$').hasMatch(info.version)) AppConfig.version = info.version;
  } catch (_) {}

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ErrorWidget.builder = (details) => kDebugMode ? ErrorWidget(details.exception) : const Material(child: CrashView());

  runApp(const ProviderScope(child: YunakApp()));
}

class YunakApp extends ConsumerWidget {
  const YunakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Yunak',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      routerConfig: router,
      scaffoldMessengerKey: messengerKey,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    );
  }
}
