import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Đặt hướng màn hình là portrait trên thiết bị di động
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Converter & Signature',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64B5F6), // Màu xanh nhẹ (Light Blue 300)
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2196F3), // Light Blue 500
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF2196F3), // Light Blue 500
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withOpacity(0.1),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3), // Light Blue 500
            foregroundColor: Colors.white,
            elevation: 1,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2196F3), // Light Blue 500
            side: const BorderSide(color: Color(0xFF2196F3)), // Light Blue 500
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF2196F3), // Light Blue 500
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFE3F2FD), // Light Blue 50
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF2196F3)), // Light Blue 500
          ),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Color(0xFF2196F3), // Light Blue 500
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Color(0xFF2196F3), // Light Blue 500
              width: 2.0,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64B5F6), // Light Blue 300
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
