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
  late Future<dynamic> _historial;
  String _rol = '';
  bool _sesionPreparada = false; 

  @override
  void initState() {
    super.initState();
    _sesionPreparada = widget.cita['sesionEstado'] != null;
    _cargarRol();
    _cargarDatos();
  }

  void _cargarRol() async {
    final rol = await widget.api.leerDato('rol');
    if (mounted) setState(() => _rol = rol ?? '');
  }

  void _cargarDatos() {
    final pacienteId = widget.cita['pacienteId'] ?? widget.cita['id'];
    if (pacienteId == null) return;

    // Usamos el endpoint del historial para ambas pestañas
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
    
    if (guardada == true) {
      if (esEnfermera) {
        if (mounted) Navigator.pop(context, true); 
      } else {
        setState(() { _cargarDatos(); _sesionPreparada = true; }); 
      }
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      final dt = DateTime.parse(fechaStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return fechaStr; }
  }

  // =========================================================
  // DISEÑO DE TARJETA DETALLADA (Se usa en ambas pestañas)
  // =========================================================
  Widget _construirTarjetaSesion(Map s) {
    final esPendiente = s['estado'] == 'PENDIENTE';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), 
        side: BorderSide(color: esPendiente ? Colors.orange.shade200 : Colors.transparent)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera (Tratamiento y Estado)
            Row(
              children: [
                Icon(esPendiente ? Icons.hourglass_empty : Icons.check_circle, color: esPendiente ? Colors.orange : Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${s['tipoTratamiento'].toString().replaceAll('_', ' ')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: esPendiente ? Colors.orange.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    s['estado'].toString(),
                    style: TextStyle(color: esPendiente ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const Divider(height: 20),
            
            // Fecha
            Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(_formatearFecha(s['fecha'].toString()), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ]),
            const SizedBox(height: 8),

            // Signos vitales
            Text('Signos Vitales (Enfermería):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade800)),
            Wrap(
              spacing: 12, runSpacing: 4,
              children: [
                Text('Presión: ${s['presion'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                Text('Temp: ${s['temperatura'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                Text('FC: ${s['fc'] ?? '-'} lpm', style: const TextStyle(fontSize: 13)),
                Text('FR: ${s['fr'] ?? '-'} rpm', style: const TextStyle(fontSize: 13)),
                Text('SpO2: ${s['spo2'] ?? '-'}%', style: const TextStyle(fontSize: 13)),
                Text('Peso: ${s['peso'] ?? '-'} kg', style: const TextStyle(fontSize: 13)),
                Text('Talla: ${s['talla'] ?? '-'} cm', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),

            // Datos del médico
            if (s['dosis'] != null) ...[
              Text('Tratamiento (Médico):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800)),
              Text('Dosis: ${s['dosis']} | Duración: ${s['duracionMinutos']} min', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
            ],

            // Observaciones
            if (s['observaciones'] != null && s['observaciones'].toString().isNotEmpty) ...[
              Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800)),
              Text(s['observaciones'].toString(), style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
            ],

            // Quién lo registró
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Registrado por: ${s['registradoPor'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paciente = widget.cita['paciente'] ?? 'Paciente';
    final documento = widget.cita['documento'] ?? 'S/N';
    final sesionEstado = _sesionPreparada ? 'PENDIENTE' : null;

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
              child: FutureBuilder<dynamic>(
                future: _historial,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  
                  final listaCompleta = snapshot.data as List? ?? [];
                  
                  // Filtramos las sesiones PENDIENTES para la primera pestaña
                  final sesionesPendientes = listaCompleta.where((s) => s['estado'] == 'PENDIENTE').toList();

                  return TabBarView(
                    children: [
                      // PESTAÑA 1: TRATAMIENTOS ACTIVOS (Solo pendientes)
                      sesionesPendientes.isEmpty 
                        ? const Center(child: Text('No hay tratamientos activos pendientes.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16), 
                            itemCount: sesionesPendientes.length,
                            itemBuilder: (context, index) => _construirTarjetaSesion(sesionesPendientes[index] as Map),
                          ),
                          
                      // PESTAÑA 2: HISTORIAL COMPLETO
                      listaCompleta.isEmpty 
                        ? const Center(child: Text('No hay sesiones registradas.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16), 
                            itemCount: listaCompleta.length,
                            itemBuilder: (context, index) => _construirTarjetaSesion(listaCompleta[index] as Map),
                          ),
                    ],
                  );
                },
              ),
            ),
            
            // Botón de acción inferior
            if (!(_rol == 'ENFERMERA' && sesionEstado != null))
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