import 'package:flutter/material.dart';

import '../core/api_client.dart';
import 'appointments_screen.dart';
import 'billing_screen.dart';
import 'patients_screen.dart';
import 'reports_screen.dart';
import 'sessions_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import 'resources_screen.dart'; // <--- NUEVO IMPORT AGREGADO

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _rol = '';
  bool _cargandoRol = true;
  bool _cerrandoSesion = false;
  late Future<dynamic> _resumen;

  @override
  void initState() {
    super.initState();
    _resumen = widget.api.get('/reportes/resumen');
    _leerRol();
  }

  Future<void> _leerRol() async {
    try {
      final rol = await widget.api.leerDato('rol');
      if (!mounted) return;
      setState(() { _rol = rol?.trim().toUpperCase() ?? ''; _cargandoRol = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoRol = false);
    }
  }

  bool get _administrativo => _rol == 'ADMIN' || _rol == 'RECEPCIONISTA';
  bool get _clinico => _rol == 'ADMIN' || _rol == 'MEDICO' || _rol == 'ENFERMERA';
  bool get _esAdmin => _rol == 'ADMIN';
  bool get _esMedico => _rol == 'MEDICO';
  bool get _esEnfermera => _rol == 'ENFERMERA';

  void _cargarResumen() => _resumen = widget.api.get('/reportes/resumen');
  void _actualizarResumen() => setState(() => _cargarResumen());

  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;
    setState(() => _cerrandoSesion = true);
    try { await widget.onLogout(); } 
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); } 
    finally { if (mounted) setState(() => _cerrandoSesion = false); }
  }

  void _abrir(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _abrirMenuMas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              CircleAvatar(radius: 30, backgroundColor: const Color(0xFF075BA8).withValues(alpha: 0.1), child: const Icon(Icons.person, size: 35, color: Color(0xFF075BA8))),
              const SizedBox(height: 10),
              Text('Rol: $_rol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF075BA8)),
                title: const Text('Configuración'),
                onTap: () { Navigator.pop(context); _abrir(SettingsScreen(api: widget.api, onLogout: widget.onLogout)); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _cerrarSesion(); },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  List<_ModuleItem> _crearModulos() {
    return [
      // PACIENTES: Solo Admin, Recepcionista y Enfermera. (El Medico NO ve la lista general)
      if (_administrativo || _esEnfermera)
        _ModuleItem('Pacientes', Icons.group_outlined, () => _abrir(PatientsScreen(api: widget.api))),
      
      // AGENDAMIENTO: Todos
      _ModuleItem('Agendamiento', Icons.calendar_today_outlined, () => _abrir(AppointmentsScreen(api: widget.api))),
      
      // TRATAMIENTOS: Clinicos (Aqui esta el historial clinico general)
      if (_clinico) 
        _ModuleItem('Tratamientos', Icons.medical_services_outlined, () => _abrir(SessionsScreen(api: widget.api))),
      
      // FACTURACIÓN Y REPORTES: Administrativos
      if (_administrativo) _ModuleItem('Facturación', Icons.receipt_long_outlined, () => _abrir(BillingScreen(api: widget.api))),
      if (_administrativo) _ModuleItem('Reportes', Icons.insert_chart_outlined, () => _abrir(ReportsScreen(api: widget.api))),
      
      // USUARIOS Y EQUIPOS: Solo Admin
      if (_esAdmin) _ModuleItem('Usuarios', Icons.people_outline, () => _abrir(UsersScreen(api: widget.api))),
      if (_esAdmin) _ModuleItem('Equipos', Icons.bed_outlined, () => _abrir(ResourcesScreen(api: widget.api))), // <--- NUEVO MÓDULO
      
      _ModuleItem('Configuración', Icons.settings_outlined, () => _abrir(SettingsScreen(api: widget.api, onLogout: widget.onLogout))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final modules = _crearModulos();
    
    // CONSTRUIMOS LA BARRA INFERIOR DINÁMICAMENTE SEGÚN EL ROL
    List<BottomNavigationBarItem> navItems = [];
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'));
    if (_administrativo || _esEnfermera) {
      navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Pacientes'));
    }
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Agenda'));
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'Más'));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SafeArea(
        child: _cargandoRol ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF075BA8), shape: BoxShape.circle), child: const Icon(Icons.medical_services, color: Colors.white, size: 32)),
                    const SizedBox(height: 10),
                    const Text('CIOMED', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF075BA8), letterSpacing: 1.5)),
                  ],
                ),
                Positioned(right: 0, top: 0, child: IconButton(tooltip: 'Cerrar sesión', onPressed: _cerrandoSesion ? null : _cerrarSesion, icon: _cerrandoSesion ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout, color: Color(0xFF075BA8)))),
              ],
            ),
            const SizedBox(height: 30),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1),
              itemBuilder: (context, index) {
                final item = modules[index];
                return Material(
                  color: Colors.white, borderRadius: BorderRadius.circular(16), elevation: 1.5, shadowColor: Colors.black12,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16), onTap: item.action,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: const Color(0xFF075BA8), size: 34),
                        const SizedBox(height: 12),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(item.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16324F), fontSize: 13))),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            if (_administrativo) ...[
              const Text('Resumen del sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
              const SizedBox(height: 12),
              FutureBuilder<dynamic>(
                future: _resumen,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator()));
                  if (snapshot.hasError) return Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [const Text('No se pudo cargar el resumen.', style: TextStyle(color: Colors.blueGrey)), TextButton.icon(onPressed: _actualizarResumen, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])));
                  if (snapshot.data is! Map) return const Text('No hay información disponible.');
                  final data = snapshot.data as Map;
                  return Row(
                    children: [
                      _SummaryCard(label: 'Pacientes', value: '${data['pacientesActivos'] ?? 0}', icon: Icons.people_outline),
                      const SizedBox(width: 12),
                      _SummaryCard(label: 'Citas hoy', value: '${data['citasDeHoy'] ?? 0}', icon: Icons.event_available_outlined),
                      const SizedBox(width: 12),
                      _SummaryCard(label: 'Sesiones', value: '${data['sesionesDeHoy'] ?? 0}', icon: Icons.monitor_heart_outlined),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
            const Text('MedOzone Gestión movil CIOMED', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (_administrativo || _esEnfermera) {
            // Flujo con 4 botones
            if (index == 1) _abrir(PatientsScreen(api: widget.api));
            if (index == 2) _abrir(AppointmentsScreen(api: widget.api));
            if (index == 3) _abrirMenuMas();
          } else {
            // Flujo Medico con 3 botones (sin pacientes)
            if (index == 1) _abrir(AppointmentsScreen(api: widget.api));
            if (index == 2) _abrirMenuMas();
          }
        },
        type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFF075BA8), unselectedItemColor: Colors.blueGrey,
        showUnselectedLabels: true, backgroundColor: Colors.white, elevation: 10,
        items: navItems, // <--- AQUI SE ASIGNA LA LISTA DINAMICA
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem(this.title, this.icon, this.action);
  final String title; final IconData icon; final VoidCallback action;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label; final String value; final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(12), elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF075BA8)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16324F))),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }
}