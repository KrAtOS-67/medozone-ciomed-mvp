import 'package:flutter/material.dart';
import '../core/api_client.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<dynamic> _sesiones = [];
  bool _cargando = true;
  String? _error;
  final TextEditingController _buscador = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargarSesiones();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarSesiones() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final data = await widget.api.get('/sesiones');
      if (!mounted) return;
      setState(() { _sesiones = data as List; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _cargando = false; });
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      final dt = DateTime.parse(fechaStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return fechaStr; }
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _sesiones.where((s) {
      final map = s as Map;
      final paciente = (map['paciente']?.toString() ?? '').toLowerCase();
      return paciente.contains(_filtro.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Historial Clínico Global'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)), onPressed: _cargarSesiones)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              controller: _buscador,
              onChanged: (v) => setState(() => _filtro = v),
              decoration: InputDecoration(
                hintText: 'Buscar por paciente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator())
              : _error != null 
                ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                : listaFiltrada.isEmpty
                  ? const Center(child: Text('No hay sesiones registradas.', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarSesiones,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: listaFiltrada.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = listaFiltrada[index] as Map;
                          final tratamiento = (s['tipoTratamiento']?.toString() ?? '').replaceAll('_', ' ');
                          
                          return Card(
                            elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person, color: Color(0xFF075BA8)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(s['paciente']?.toString() ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)))),
                                      Text(_formatearFecha(s['fecha']?.toString() ?? ''), style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                    ],
                                  ),
                                  const Divider(),
                                  Text('Tratamiento: $tratamiento', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  // CORREGIDO AQUI: duracionMinutos
                                  Text('Dosis: ${s['dosis'] ?? '-'} | Presión: ${s['presion'] ?? '-'} | Duración: ${s['duracionMinutos'] ?? '-'} min'),
                                  const SizedBox(height: 4),
                                  Text('Observaciones: ${s['observaciones'] ?? 'Ninguna'}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                                  const SizedBox(height: 8),
                                  Align(alignment: Alignment.centerRight, child: Text('Registrado por: ${s['registradoPor']}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}