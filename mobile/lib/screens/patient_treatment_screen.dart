import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'session_form_screen.dart';
import 'nurse_form_screen.dart';

class PatientTreatmentScreen extends StatefulWidget {
  const PatientTreatmentScreen({super.key, required this.api, required this.cita});
  final ApiClient api;
  final Map cita;

  @override
  State<PatientTreatmentScreen> createState() => _PatientTreatmentScreenState();
}

class _PatientTreatmentScreenState extends State<PatientTreatmentScreen> {
  late Future<dynamic> _resumen;
  late Future<dynamic> _historial;
  String _rol = '';

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _cargarDatos();
  }

  void _cargarRol() async {
    final rol = await widget.api.leerDato('rol');
    if (mounted) setState(() => _rol = rol ?? '');
  }

  void _cargarDatos() {
    final pacienteId = widget.cita['pacienteId'];
    _resumen = widget.api.get('/sesiones/paciente/$pacienteId/resumen');
    _historial = widget.api.get('/sesiones/paciente/$pacienteId');
  }

  Future<void> _registrarSesion() async {
    final esEnfermera = _rol == 'ENFERMERA';
    final sesionId = widget.cita['sesionId'];
    final sesionData = (sesionId != null) ? {
      'id': sesionId,
      'presion': widget.cita['presionEnfermeria'],
      'temperatura': widget.cita['temperaturaEnfermeria'],
      'fc': widget.cita['fcEnfermeria'],
      'fr': widget.cita['frEnfermeria'],
      'spo2': widget.cita['spo2Enfermeria'],
      'peso': widget.cita['pesoEnfermeria'],
      'talla': widget.cita['tallaEnfermeria'],
    } : null;

    final pantalla = esEnfermera
        ? NurseFormScreen(api: widget.api, cita: widget.cita)
        : SessionFormScreen(api: widget.api, cita: widget.cita, sesion: sesionData);

    final guardada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => pantalla));
    if (guardada == true) setState(() { _cargarDatos(); });
  }

  String _formatearFecha(String fechaStr) {
    try {
      final dt = DateTime.parse(fechaStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return fechaStr; }
  }

  @override
  Widget build(BuildContext context) {
    final paciente = widget.cita['paciente'] ?? 'Paciente';
    final documento = widget.cita['documento'] ?? 'S/N';
    final sesionEstado = widget.cita['sesionEstado'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Tratamiento del paciente'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(radius: 30, backgroundColor: const Color(0xFF075BA8).withValues(alpha: 0.1), child: const Icon(Icons.person, size: 35, color: Color(0xFF075BA8))),
                const SizedBox(width: 15),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(paciente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 4),
                  Text('CI: $documento', style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
                ]),
              ]),
            ),
            const TabBar(labelColor: Color(0xFF075BA8), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF075BA8), tabs: [Tab(text: 'Tratamientos Activos'), Tab(text: 'Historial de Sesiones')]),
            Expanded(
              child: TabBarView(
                children: [
                  FutureBuilder<dynamic>(
                    future: _resumen,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      final lista = snapshot.data as List? ?? [];
                      if (lista.isEmpty) return const Center(child: Text('No hay tratamientos registrados.', style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final t = lista[index] as Map;
                          return Card(elevation: 1, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.medical_services, color: Color(0xFF075BA8), size: 30),
                              title: Text(t['tipoTratamiento'].toString().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text('Inicia: ${_formatearFecha(t['inicio'].toString())} - ${t['totalSesiones']} sesiones', style: const TextStyle(color: Colors.blueGrey)),
                            ));
                        },
                      );
                    },
                  ),
                  FutureBuilder<dynamic>(
                    future: _historial,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      final lista = snapshot.data as List? ?? [];
                      if (lista.isEmpty) return const Center(child: Text('No hay sesiones anteriores.', style: TextStyle(color: Colors.grey)));
                      return ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final s = lista[index] as Map;
                          final esPendiente = s['estado'] == 'PENDIENTE';
                          return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: esPendiente ? Colors.orange.shade200 : Colors.transparent)),
                            child: ListTile(
                              leading: Icon(esPendiente ? Icons.hourglass_empty : Icons.check_circle, color: esPendiente ? Colors.orange : Colors.green),
                              title: Text('${s['tipoTratamiento'].toString().replaceAll('_', ' ')} - ${_formatearFecha(s['fecha'].toString())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Estado: ${s['estado']}\nPresión: ${s['presion'] ?? '-'} | Dosis: ${s['dosis'] ?? '-'}'),
                              isThreeLine: true,
                            ));
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    onPressed: _registrarSesion,
                    icon: Icon(_rol == 'ENFERMERA' ? Icons.vaccines : Icons.add_circle_outline),
                    label: Text(_rol == 'ENFERMERA' ? 'Registrar Signos Vitales' : (sesionEstado == 'PENDIENTE' ? 'Completar Sesión Médica' : 'Registrar Sesión Completa')),
                    style: FilledButton.styleFrom(
                      backgroundColor: _rol == 'ENFERMERA' ? Colors.orange : (sesionEstado == 'PENDIENTE' ? Colors.green : const Color(0xFF075BA8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}