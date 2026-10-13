import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  final container = ProviderContainer();
  final push = container.read(pushServiceProvider);
  await push.init();
  // Registra il dispositivo per le push a ogni login (e all'avvio con sessione valida).
  container.listen(sessionProvider, (previous, next) {
    final user = next.value;
    if (user != null && previous?.value?.id != user.id) push.onLogin();
  }, fireImmediately: true);

  runApp(UncontrolledProviderScope(container: container, child: const GymBroApp()));
}

class GymBroApp extends ConsumerWidget {
  const GymBroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GymBro',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
