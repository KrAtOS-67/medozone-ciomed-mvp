import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();

  runApp(
    MedOzoneApp(api: api),
  );
}

class MedOzoneApp extends StatefulWidget {
  const MedOzoneApp({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  State<MedOzoneApp> createState() => _MedOzoneAppState();
}

class _MedOzoneAppState extends State<MedOzoneApp> {
  bool _cargando = true;
  bool _autenticado = false;

  @override
  void initState() {
    super.initState();
    _restaurarSesion();
  }

  // Comprobar si existe una sesión guardada.
  Future<void> _restaurarSesion() async {
    try {
      final existe = await widget.api.validarSesion();

      if (!mounted) return;

      setState(() {
        _autenticado = existe;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _autenticado = false;
        _cargando = false;
      });
    }
  }

  // Acceder a la aplicación después del login.
  void _entrar() {
    if (!mounted) return;

    setState(() {
      _autenticado = true;
    });
  }

  // Cerrar sesión.
  Future<void> _salir() async {
    try {
      await widget.api.cerrarSesion();

      if (!mounted) return;

      setState(() {
        _autenticado = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cerrar la sesión. Inténtalo nuevamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF075BA8);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedOzone CIOMED',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: azul,
          primary: azul,
        ),

        scaffoldBackgroundColor: const Color(0xFFF4F7FB),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF16324F),
          centerTitle: false,
          elevation: 0,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azul,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: _cargando
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _autenticado
              ? HomeScreen(
                  api: widget.api,
                  onLogout: _salir,
                )
              : LoginScreen(
                  api: widget.api,
                  onLogin: _entrar,
                ),
    );
  }
}