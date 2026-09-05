import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'router.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PriceCheckerApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class PriceCheckerApp extends StatelessWidget {
  const PriceCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp.router(
          title: 'ตรวจสอบราคาสินค้า',
          debugShowCheckedModeBanner: false,
          theme: appThemeLight(),
          darkTheme: appThemeDark(),
          themeMode: mode,
          routerConfig: appRouter,
        );
      }
    );
  }
}
