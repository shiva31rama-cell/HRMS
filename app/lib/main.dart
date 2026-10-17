import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiService();
  final user = await api.restoreSession();
  runApp(HRMSApp(api: api, initialUser: user));
}

class HRMSApp extends StatefulWidget {
  const HRMSApp({super.key, required this.api, required this.initialUser});
  final ApiService api;
  final Map<String, dynamic>? initialUser;

  @override
  State<HRMSApp> createState() => _HRMSAppState();
}

class _HRMSAppState extends State<HRMSApp> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF176B58);
    return MaterialApp(
      title: 'Hostel Room Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F7F6), surfaceTintColor: Colors.transparent, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE4ECE7)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAF9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: brand, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: _user == null
          ? LoginScreen(api: widget.api, onAuthenticated: (user) => setState(() => _user = user))
          : HomeShell(
              api: widget.api,
              user: _user!,
              onLogout: () async {
                await widget.api.clearToken();
                if (mounted) setState(() => _user = null);
              },
            ),
    );
  }
}
