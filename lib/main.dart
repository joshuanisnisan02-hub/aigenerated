import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LakbayKasaysayanApp());
}

class LakbayKasaysayanApp extends StatelessWidget {
  const LakbayKasaysayanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F0E3),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF173A5E),
        primary: const Color(0xFF173A5E),
        secondary: const Color(0xFFB88A44),
        surface: const Color(0xFFFFFCF5),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakbay Kasaysayan AI',
      theme: base.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFCF5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x1F173A5E)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
