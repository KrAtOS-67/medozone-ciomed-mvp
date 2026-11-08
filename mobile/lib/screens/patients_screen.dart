import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'patient_form_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<dynamic> _pacientes = [];
  bool _cargando = true;
  String? _error;
  final TextEditingController _buscador = TextEditingController();
  String _filtro = '';
  String _rol = '';
  bool _cargandoRol = true;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
    _leerRol();
  }

  @override
  void dispose() { _buscador.dispose(); super.dispose(); }

  Future<void> _cargarPacientes() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final data = await widget.api.get('/pacientes');
      if (!mounted) return;
      setState(() { _pacientes = data as List; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _leerRol() async {
    final rol = await widget.api.leerDato('rol');
    if (!mounted) return;
    setState(() { _rol = rol ?? ''; _cargandoRol = false; });
  }

  bool get _puedeEditar => _rol == 'ADMIN' || _rol == 'RECEPCIONISTA' || _rol == 'MEDICO';

  Future<void> _nuevoPaciente() async {
    final creado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PatientFormScreen(api: widget.api)));
    if (creado == true) _cargarPacientes();
  }

  Future<void> _editarPaciente(Map paciente) async {
    final editado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PatientFormScreen(api: widget.api, paciente: paciente)));
    if (editado == true) _cargarPacientes();
  }

  Future<void> _darDeAlta(Map paciente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de Alta'),
        content: Text('¿Estás seguro de dar de alta a ${paciente['nombres']}? Ya no aparecerá para agendar nuevas citas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dar de Alta')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await widget.api.patch('/pacientes/${paciente['id']}/alta', {});
      _cargarPacientes();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paciente dado de alta.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _calcularEdad(String? fechaNacimientoStr) {
    if (fechaNacimientoStr == null || fechaNacimientoStr.isEmpty) return 'Sin edad';
    final fechaNacimiento = DateTime.tryParse(fechaNacimientoStr);
    if (fechaNacimiento == null) return 'Sin edad';
    final hoy = DateTime.now();
    int edad = hoy.year - fechaNacimiento.year;
    if (hoy.month < fechaNacimiento.month || (hoy.month == fechaNacimiento.month && hoy.day < fechaNacimiento.day)) edad--;
    return '$edad años';
  }

  String _normalizar(String texto) {
    return texto.toLowerCase().replaceAll('á','a').replaceAll('é','e').replaceAll('í','i').replaceAll('ó','o').replaceAll('ú','u').replaceAll('ñ','n');
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _pacientes.where((p) {
      final m = p as Map;
      final nombres = _normalizar(m['nombres']?.toString() ?? '');
      final apellidos = _normalizar(m['apellidos']?.toString() ?? '');
      final documento = _normalizar(m['documento']?.toString() ?? '');
      final filtroNorm = _normalizar(_filtro);
      return nombres.contains(filtroNorm) || apellidos.contains(filtroNorm) || documento.contains(filtroNorm);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)), onPressed: () => Navigator.pop(context)),
        title: const Text('Pacientes', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)), onPressed: _cargando ? null : _cargarPacientes)],
      ),
      floatingActionButton: _cargandoRol || !_puedeEditar ? null : FloatingActionButton(
        onPressed: _nuevoPaciente, backgroundColor: const Color(0xFF075BA8),
        shape: const CircleBorder(), child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: TextField(
              controller: _buscador,
              onChanged: (v) => setState(() => _filtro = v),
              decoration: InputDecoration(
                hintText: 'Buscar paciente...', hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true, fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF075BA8))),
              ),
            ),
          ),
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text('Error: $_error'))
                : listaFiltrada.isEmpty
                  ? Center(child: Text(_filtro.isEmpty ? 'No hay pacientes registrados.' : 'No se encontraron resultados.', style: const TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarPacientes,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 80),
                        itemCount: listaFiltrada.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1, indent: 80),
                        itemBuilder: (context, index) {
                          final p = Map<String, dynamic>.from(listaFiltrada[index] as Map);
                          final estado = p['estadoClinico']?.toString() ?? 'NUEVO';
                          final edad = _calcularEdad(p['fechaNacimiento']?.toString());
                          final ci = p['documento']?.toString();
                          final documentoStr = (ci == null || ci.isEmpty) ? 'Sin CI' : 'CI: $ci';

                          Color colorEstado;
                          String textoEstado;
                          if (estado == 'EN_TRATAMIENTO') { colorEstado = Colors.teal; textoEstado = 'En tratamiento'; }
                          else if (estado == 'EN_SEGUIMIENTO') { colorEstado = Colors.blue; textoEstado = 'En seguimiento'; }
                          else if (estado == 'ALTA') { colorEstado = Colors.green; textoEstado = 'Alta'; }
                          else { colorEstado = Colors.grey; textoEstado = 'Nuevo'; }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(radius: 26, backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, color: Color(0xFF075BA8), size: 30)),
                            title: Text('${p['nombres']} ${p['apellidos']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('$documentoStr - $edad', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: colorEstado.withValues(alpha: 0.3))),
                                  child: Text(textoEstado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorEstado)),
                                ),
                              ],
                            ),
                            trailing: (_rol == 'MEDICO' || _rol == 'ADMIN') 
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                  onSelected: (val) {
                                    if (val == 'editar') _editarPaciente(p);
                                    if (val == 'alta') _darDeAlta(p);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'editar', child: Text('Editar paciente')),
                                    if (p['estadoClinico'] != 'ALTA') const PopupMenuItem(value: 'alta', child: Text('Dar de Alta', style: TextStyle(color: Colors.green))),
                                  ],
                                )
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: _puedeEditar ? () => _editarPaciente(p) : null,
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