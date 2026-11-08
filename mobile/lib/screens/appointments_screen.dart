import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'appointment_form_screen.dart';
import 'patient_treatment_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _fecha = DateTime.now();
  List<dynamic> _citas = [];
  bool _cargandoCitas = true;
  String? _errorCitas;
  String _rol = '';
  bool _cargandoRol = true;
  List<dynamic> _historial = [];
  bool _cargandoHistorial = true;
  final TextEditingController _buscadorHistorial = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarCitas();
    _cargarHistorial();
    _leerRol();
  }

  @override
  void dispose() { _buscadorHistorial.dispose(); super.dispose(); }

  Future<void> _leerRol() async {
    final rol = await widget.api.leerDato('rol');
    if (!mounted) return;
    setState(() { _rol = rol ?? ''; _cargandoRol = false; });
  }

  String _fechaTexto(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _cargarCitas() async {
    if (mounted) setState(() { _cargandoCitas = true; _errorCitas = null; });
    try {
      final data = await widget.api.get('/citas?fecha=${_fechaTexto(_fecha)}');
      if (!mounted) return;
      setState(() { _citas = data as List; _cargandoCitas = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorCitas = e.toString().replaceFirst('Exception: ', ''); _cargandoCitas = false; });
    }
  }

  Future<void> _cargarHistorial([String filtro = '']) async {
    if (mounted) setState(() { _cargandoHistorial = true; });
    try {
      final q = filtro.isNotEmpty ? '?paciente=${Uri.encodeComponent(filtro)}' : '';
      final data = await widget.api.get('/citas/historial$q');
      if (!mounted) return;
      setState(() { _historial = data as List; _cargandoHistorial = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargandoHistorial = false; });
    }
  }

  bool get _esMedico => _rol == 'MEDICO';
  bool get _esEnfermera => _rol == 'ENFERMERA';
  bool get _esRecepcion => _rol == 'ADMIN' || _rol == 'RECEPCIONISTA';

  Future<void> _nuevaCita() async {
    final creada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(api: widget.api)));
    if (creada == true) _cargarCitas();
  }

  Future<void> _reprogramar(Map cita) async {
    final actualizada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(api: widget.api, cita: Map<String, dynamic>.from(cita))));
    if (actualizada == true) _cargarCitas();
  }

  Future<void> _abrirPerfilPaciente(Map cita) async {
    final actualizada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PatientTreatmentScreen(api: widget.api, cita: cita)));
    if (mounted) { _cargarCitas(); _cargarHistorial(); }
  }

  Future<void> _cambiarEstado(Map cita, String nuevoEstado) async {
    try {
      await widget.api.patch('/citas/${cita['id']}/estado', {'estado': nuevoEstado});
      if (!mounted) return;
      _cargarCitas(); _cargarHistorial();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado cambiado a $nuevoEstado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _seleccionarFecha() async {
    final date = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (date != null) { setState(() => _fecha = date); _cargarCitas(); }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoRol) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          title: const Text('Agendamiento'),
          backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF075BA8), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF075BA8),
            tabs: [Tab(text: 'Mi Agenda', icon: Icon(Icons.calendar_today)), Tab(text: 'Historial Clínico', icon: Icon(Icons.history))],
          ),
        ),
        body: TabBarView(children: [_buildTabAgenda(), _buildTabHistorial()]),
        floatingActionButton: _esRecepcion ? FloatingActionButton(onPressed: _nuevaCita, backgroundColor: const Color(0xFF075BA8), child: const Icon(Icons.add, color: Colors.white)) : null,
      ),
    );
  }

  Widget _buildTabAgenda() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Card(
            elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFF075BA8)),
              title: Text(_fechaTexto(_fecha), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text('Toca para cambiar el día'),
              trailing: IconButton(onPressed: _seleccionarFecha, icon: const Icon(Icons.edit_calendar)),
              onTap: _seleccionarFecha,
            ),
          ),
        ),
        Expanded(
          child: _cargandoCitas
            ? const Center(child: CircularProgressIndicator())
            : _errorCitas != null
              ? Center(child: Text('Error: $_errorCitas', style: const TextStyle(color: Colors.red)))
              : _citas.isEmpty
                ? const Center(child: Text('No hay citas para este día.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _cargarCitas,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                      itemCount: _citas.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cita = _citas[index] as Map;
                        final DateTime? inicio = DateTime.tryParse(cita['inicio']?.toString() ?? '');
                        final hora = inicio == null ? '--:--' : '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
                        final estado = cita['estado']?.toString() ?? 'DESCONOCIDO';
                        final esActiva = estado == 'PROGRAMADA' || estado == 'CONFIRMADA';
                        final sesionEstado = cita['sesionEstado'];

                        return Card(
                          elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.access_time, color: Color(0xFF075BA8)),
                                  const SizedBox(width: 8),
                                  Text(hora, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  const Spacer(),
                                  _StatusPill(status: estado),
                                ]),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: Text(cita['paciente']?.toString() ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  if (sesionEstado == 'PENDIENTE')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                      child: const Row(children: [
                                        Icon(Icons.check_circle, size: 12, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text('Preparado por Enfermería', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ]),
                                    )
                                  else if (sesionEstado == null && (_esMedico || _esEnfermera))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                      child: const Row(children: [
                                        Icon(Icons.hourglass_empty, size: 12, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Sin preparar', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ]),
                                    ),
                                ]),
                                if (cita['documento'] != null) Text('CI: ${cita['documento']}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                const SizedBox(height: 5),
                                Text((cita['tipoTratamiento']?.toString() ?? 'Tratamiento').replaceAll('_', ' '), style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 7),
                                Text('Profesional: ${cita['profesional'] ?? 'No asignado'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                Text('Recurso: ${cita['recurso'] ?? 'No asignado'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                if (esActiva) ...[
                                  const SizedBox(height: 12),
                                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    if (_esMedico || _esEnfermera) ...[
                                      OutlinedButton.icon(
                                        onPressed: () => _cambiarEstado(cita, 'AUSENTE'),
                                        icon: const Icon(Icons.person_off, size: 18, color: Colors.orange),
                                        label: const Text('Ausente', style: TextStyle(color: Colors.orange)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: () => _abrirPerfilPaciente(cita),
                                        icon: Icon(sesionEstado == 'PENDIENTE' ? Icons.check_circle : Icons.monitor_heart, size: 18),
                                        label: Text(sesionEstado == 'PENDIENTE' ? 'Completar Sesión' : 'Atender'),
                                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                    ],
                                    if (_esRecepcion) ...[
                                      OutlinedButton.icon(
                                        onPressed: () => _reprogramar(cita),
                                        icon: const Icon(Icons.edit_calendar, size: 18),
                                        label: const Text('Reprogramar'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _cambiarEstado(cita, 'CANCELADA'),
                                        icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                        label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                      ),
                                    ]
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildTabHistorial() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: TextField(
            controller: _buscadorHistorial,
            onChanged: (v) => _cargarHistorial(v),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o CI...', prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscadorHistorial.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscadorHistorial.clear(); _cargarHistorial(); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true, fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _cargandoHistorial
            ? const Center(child: CircularProgressIndicator())
            : _historial.isEmpty
              ? const Center(child: Text('No hay pacientes en el historial.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _historial.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = _historial[index] as Map;
                    final fecha = DateTime.tryParse(c['inicio'].toString());
                    final fechaStr = fecha != null ? '${fecha.day}/${fecha.month}/${fecha.year}' : '---';
                    final estado = c['estado']?.toString() ?? '';
                    final color = estado == 'ATENDIDA' ? Colors.green : Colors.orange;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.person, color: color)),
                        title: Text(c['paciente'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('CI: ${c['documento'] ?? 'S/N'} · $fechaStr\n${(c['tipoTratamiento'] ?? '').toString().replaceAll('_', ' ')}'),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(estado, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final Color color = status == 'ATENDIDA' ? Colors.green : status == 'CONFIRMADA' ? Colors.teal : status == 'CANCELADA' ? Colors.red : status == 'AUSENTE' ? Colors.orange : const Color(0xFF075BA8);
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }
}