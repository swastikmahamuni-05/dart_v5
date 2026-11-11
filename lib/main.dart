import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/tank_service.dart';
import 'services/api_service.dart';
import 'providers/tank_provider.dart';
import 'services/mqtt_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => TankService()),
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(
          create: (context) => TankProvider(
            Provider.of<TankService>(context, listen: false),
            Provider.of<ApiService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MqttService(
            Provider.of<TankProvider>(context, listen: false),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'LEVELS',
      debugShowCheckedModeBanner: false,
      // Premium Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1565C0),
          secondary: Color(0xFF42A5F5),
          background: Color(0xFFF5F7FA),
          surface: Colors.white,
          onBackground: Color(0xFF1E293B),
          onSurface: Color(0xFF1E293B),
        ),
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      // Premium Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF42A5F5),
          secondary: Color(0xFF90CAF9),
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
          onBackground: Color(0xFFF8FAFC),
          onSurface: Color(0xFFF8FAFC),
        ),
        dividerColor: const Color(0xFF334155),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: themeProvider.themeMode,
      scrollBehavior: const MyCustomScrollBehavior(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  const MyCustomScrollBehavior();

  @override
  Set<ui.PointerDeviceKind> get dragDevices => {
        ui.PointerDeviceKind.touch,
        ui.PointerDeviceKind.mouse,
        ui.PointerDeviceKind.trackpad,
      };
}
