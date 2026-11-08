import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final ApiClient api;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _nombre = 'Cargando...';
  String _usuario = '...';
  String _rol = '...';
  bool _cargando = true;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final nombre = await widget.api.leerDato('nombre');
    final usuario = await widget.api.leerDato('usuario');
    final rol = await widget.api.leerDato('rol');

    if (!mounted) return;
    setState(() {
      _nombre = nombre ?? 'Usuario CIOMED';
      _usuario = usuario ?? 'usuario';
      _rol = rol ?? 'SIN ROL';
      _cargando = false;
    });
  }

  Future<void> _confirmarCierreSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _cerrandoSesion = true);
    try {
      await widget.onLogout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cerrandoSesion = false);
    }
  }

  // Navegar a la pantalla de cambio de contraseña
  void _abrirCambioContrasena() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // =============================================
                // SECCIÓN: PERFIL DEL USUARIO
                // =============================================
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: const Color(0xFF075BA8).withValues(alpha: 0.1),
                          child: const Icon(Icons.person, size: 40, color: Color(0xFF075BA8)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nombre,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@$_usuario',
                                style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF075BA8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _rol,
                                  style: const TextStyle(
                                    color: Color(0xFF075BA8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader(titulo: 'Seguridad'),

                // =============================================
                // SECCIÓN: SEGURIDAD
                // =============================================
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: Color(0xFF075BA8)),
                        title: const Text('Cambiar contraseña'),
                        subtitle: const Text('Actualiza tu clave de acceso'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _abrirCambioContrasena, // <-- Aquí navega
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF075BA8)),
                        title: const Text('Sesión activa'),
                        subtitle: const Text('Protegida con token JWT'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader(titulo: 'Acerca de'),

                // =============================================
                // SECCIÓN: ACERCA DE
                // =============================================
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Color(0xFF075BA8)),
                        title: const Text('Versión de la App'),
                        subtitle: const Text('MedOzone v1.0.0'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.business_outlined, color: Color(0xFF075BA8)),
                        title: const Text('Clínica CIOMED'),
                        subtitle: const Text('Ozonoterapia · Oxigenoterapia Hiperbárica'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.headset_mic_outlined, color: Color(0xFF075BA8)),
                        title: const Text('Soporte Técnico'),
                        subtitle: const Text('soporte@ciomed.bo'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contacta a soporte en soporte@ciomed.bo')),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // =============================================
                // BOTÓN DE CERRAR SESIÓN
                // =============================================
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _cerrandoSesion ? null : _confirmarCierreSesion,
                    icon: _cerrandoSesion
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.logout, color: Colors.red),
                    label: Text(
                      _cerrandoSesion ? 'Cerrando sesión...' : 'Cerrar Sesión',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'MedOzone · Sistema de Gestión Clínica\n© 2026 Clínica CIOMED',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}