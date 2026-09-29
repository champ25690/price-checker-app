import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'router.dart';
import 'theme.dart';
import 'utils/pwa_manager.dart' as pwa;

import 'dart:async';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    void updateUI(ThemeMode mode) {
      final isDark = mode == ThemeMode.dark;
      pwa.updateThemeColor(isDark ? '#121212' : '#F7F8FA');
      
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ));
    }

    themeNotifier.addListener(() {
      updateUI(themeNotifier.value);
    });
    updateUI(ThemeMode.light); // Default light

    runApp(const PriceCheckerApp());
  }, (Object error, StackTrace stack) {
    runApp(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App Crash Details')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text('Error:\n$error\n\nStack:\n$stack', style: const TextStyle(color: Colors.red)),
        ),
      ),
    ));
  });
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
