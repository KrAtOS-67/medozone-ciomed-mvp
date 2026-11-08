import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, required this.api, this.cita});
  final ApiClient api;
  final Map<String, dynamic>? cita;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  static const int _duracionMinutos = 60;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pacienteCtrl = TextEditingController();
  final TextEditingController _medicoCtrl = TextEditingController();
  int? _pacienteId;
  
  DateTime _fecha = DateTime.now();
  String _tipo = 'OZONOTERAPIA';
  String? _medicoSeleccionado;
  String? _horarioSeleccionado;
  String? _recursoSeleccionado;

  bool _guardando = false;
  String? _error;

  late Future<dynamic> _pacientes;
  List<dynamic> _medicosDisponibles = [];
  List<dynamic> _horariosDisponibles = [];
  List<dynamic> _recursosDisponibles = [];

  bool _cargandoMedicos = false;
  bool _cargandoHorarios = false;
  bool _cargandoRecursos = false;

  bool get _esReprogramacion => widget.cita != null;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();

    if (_esReprogramacion) {
      _pacienteId = (widget.cita!['pacienteId'] as num?)?.toInt();
      _pacienteCtrl.text = widget.cita!['paciente']?.toString() ?? '';
      _medicoSeleccionado = widget.cita!['profesional']?.toString();
      _medicoCtrl.text = _medicoSeleccionado ?? '';
      _recursoSeleccionado = widget.cita!['recurso']?.toString();
      _tipo = widget.cita!['tipoTratamiento']?.toString() ?? 'OZONOTERAPIA';
      
      final dt = DateTime.parse(widget.cita!['inicio'].toString()).toLocal();
      _fecha = dt;
      _horarioSeleccionado = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      
      _cargarMedicosDisponibles();
    } else {
      _cargarMedicosDisponibles();
    }
  }

  void _cargarPacientes() { _pacientes = widget.api.get('/pacientes'); }

  @override
  void dispose() { 
    _pacienteCtrl.dispose(); 
    _medicoCtrl.dispose();
    super.dispose(); 
  }

  String _fechaVisible(DateTime d) {
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]} del ${d.year}';
  }

  String _fechaTexto(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime.now(), lastDate: DateTime(2035));
    if (d != null) {
      setState(() { _fecha = d; _medicoSeleccionado = null; _medicoCtrl.clear(); _horarioSeleccionado = null; _recursoSeleccionado = null; _horariosDisponibles = []; _recursosDisponibles = []; });
      if (_medicoSeleccionado != null) _cargarHorarios();
    }
  }

  Future<void> _cargarMedicosDisponibles() async {
    setState(() { _cargandoMedicos = true; _error = null; });
    try {
      final data = await widget.api.get('/citas/medicos-disponibles?tipoTratamiento=$_tipo');
      if (mounted) setState(() { _medicosDisponibles = data; _cargandoMedicos = false; });
    } catch (e) {
      if (mounted) {
        setState(() { 
          _cargandoMedicos = false; 
          _error = 'Error al buscar médicos: ${e.toString().replaceFirst("Exception: ", "")}'; 
        });
      }
    }
  }

  void _seleccionarMedico(String medico) {
    setState(() { _medicoSeleccionado = medico; _medicoCtrl.text = medico; _horarioSeleccionado = null; _recursoSeleccionado = null; _recursosDisponibles = []; _horariosDisponibles = []; });
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    setState(() { _cargandoHorarios = true; _error = null; });
    try {
      final data = await widget.api.get('/citas/disponibilidad?fecha=${_fechaTexto(_fecha)}&profesional=${Uri.encodeComponent(_medicoSeleccionado!)}');
      if (mounted) setState(() { _horariosDisponibles = data; _cargandoHorarios = false; });
    } catch (e) {
      if (mounted) {
        setState(() { 
          _cargandoHorarios = false; 
          _error = 'Error al cargar horarios: ${e.toString().replaceFirst("Exception: ", "")}'; 
        });
      }
    }
  }

  void _seleccionarHorario(String hora) {
    setState(() { _horarioSeleccionado = hora; _recursoSeleccionado = null; });
    _cargarRecursosDisponibles();
  }

  Future<void> _cargarRecursosDisponibles() async {
    setState(() => _cargandoRecursos = true);
    try {
      final recs = await widget.api.get('/recursos?tipo=$_tipo');
      List<dynamic> disponibles = [];
      for (var r in recs) {
        final slots = await widget.api.get('/citas/disponibilidad?fecha=${_fechaTexto(_fecha)}&recurso=${Uri.encodeComponent(r['nombre'])}');
        final libre = slots.any((s) => s['hora'] == _horarioSeleccionado && s['disponible'] == true);
        if (libre) disponibles.add(r);
      }
      if (mounted) setState(() { _recursosDisponibles = disponibles; _cargandoRecursos = false; });
    } catch (e) { 
      if (mounted) {
        setState(() => _cargandoRecursos = false);
      }
    }
  }

  void _abrirBuscadorPacientes(List<dynamic> pacientes) async {
    final disponibles = pacientes.where((p) => (p as Map)['estadoClinico'] != 'ALTA').toList();
    final seleccionado = await showModalBottomSheet<Map>(
      context: context, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _BuscadorModal(
        titulo: 'Seleccionar Paciente',
        items: disponibles,
        textoBusqueda: (item) => '${item['nombres']} ${item['apellidos']} - CI: ${item['documento'] ?? 'S/N'}',
        textoPrincipal: (item) => '${item['nombres']} ${item['apellidos']}',
        textoSecundario: (item) => 'CI: ${item['documento'] ?? 'S/N'}',
      ),
    );

    if (seleccionado != null) {
      setState(() { 
        _pacienteId = (seleccionado['id'] as num).toInt(); 
        _pacienteCtrl.text = '${seleccionado['nombres']} ${seleccionado['apellidos']}'; 
      });
    }
  }

  void _abrirBuscadorMedicos() async {
    final seleccionado = await showModalBottomSheet<Map>(
      context: context, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _BuscadorModal(
        titulo: 'Seleccionar Médico',
        items: _medicosDisponibles,
        textoBusqueda: (item) => '${item['nombre']} ${item['especialidad']}',
        textoPrincipal: (item) => item['nombre'],
        textoSecundario: (item) => item['especialidad'],
      ),
    );

    if (seleccionado != null) {
      _seleccionarMedico(seleccionado['nombre']);
    }
  }

  Future<void> _guardar() async {
    if (_pacienteId == null) { setState(() => _error = 'Selecciona un paciente.'); return; }
    if (_medicoSeleccionado == null) { setState(() => _error = 'Selecciona un médico.'); return; }
    if (_horarioSeleccionado == null) { setState(() => _error = 'Selecciona un horario.'); return; }
    if (_recursoSeleccionado == null) { setState(() => _error = 'Selecciona una camilla.'); return; }

    setState(() { _guardando = true; _error = null; });
    try {
      final partes = _horarioSeleccionado!.split(':');
      final inicio = DateTime(_fecha.year, _fecha.month, _fecha.day, int.parse(partes[0]), int.parse(partes[1]));
      final datos = { 'pacienteId': _pacienteId, 'profesional': _medicoSeleccionado, 'recurso': _recursoSeleccionado, 'tipoTratamiento': _tipo, 'inicio': inicio.toIso8601String(), 'duracionMinutos': _duracionMinutos, 'motivo': '' };

      if (_esReprogramacion) { await widget.api.patch('/citas/${widget.cita!['id']}/reprogramar', datos); } 
      else { await widget.api.post('/citas', datos); }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _guardando = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_esReprogramacion) return _buildFormulario(null);
    return FutureBuilder<dynamic>(
      future: _pacientes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(title: const Text('Cargando...')), body: const Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text('Error al cargar pacientes: ${snapshot.error}')));
        return _buildFormulario(snapshot.data as List);
      },
    );
  }

  Widget _buildFormulario(List<dynamic>? pacientes) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_esReprogramacion ? 'Reprogramar cita' : 'Nueva Cita'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // PASO 1: PACIENTE
            const Text('1. Selecciona el paciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pacienteCtrl,
              readOnly: true,
              onTap: () => _abrirBuscadorPacientes(pacientes!),
              decoration: InputDecoration(
                hintText: 'Toca para buscar paciente',
                prefixIcon: const Icon(Icons.person_search),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),

            // PASO 2: FECHA Y TRATAMIENTO
            const Text('2. Fecha y Tratamiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 8),
            Card(
              elevation: 1, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
              child: ListTile(
                leading: const Icon(Icons.calendar_month, color: Color(0xFF075BA8)), 
                title: Text(_fechaVisible(_fecha), style: const TextStyle(fontWeight: FontWeight.bold)), 
                subtitle: const Text('Toca para cambiar el día'),
                trailing: const Icon(Icons.edit_calendar), 
                onTap: _guardando ? null : _seleccionarFecha
              )
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de Tratamiento *', prefixIcon: Icon(Icons.medical_services_outlined), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: const [
                DropdownMenuItem(value: 'OZONOTERAPIA', child: Text('Ozonoterapia')),
                DropdownMenuItem(value: 'OXIGENOTERAPIA_HIPERBARICA', child: Text('Oxigenoterapia Hiperbárica')),
              ],
              onChanged: _guardando ? null : (v) {
                setState(() { _tipo = v!; _medicoSeleccionado = null; _medicoCtrl.clear(); _horarioSeleccionado = null; _recursoSeleccionado = null; _medicosDisponibles = []; _horariosDisponibles = []; _recursosDisponibles = []; });
                _cargarMedicosDisponibles();
              },
            ),
            const SizedBox(height: 20),

            // PASO 3: MÉDICO
            const Text('3. Profesional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicoCtrl,
              readOnly: true,
              onTap: _cargandoMedicos || _medicosDisponibles.isEmpty ? null : _abrirBuscadorMedicos,
              decoration: InputDecoration(
                hintText: _cargandoMedicos 
                    ? 'Buscando médicos...' 
                    : (_medicosDisponibles.isEmpty 
                        ? 'No hay médicos en esta área' 
                        : 'Toca para buscar médico'),
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _cargandoMedicos ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),

            // PASO 4: HORARIO
            if (_medicoSeleccionado != null) ...[
              const Text('4. Horario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 8),
              if (_cargandoHorarios)
                const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
              else if (_horariosDisponibles.isEmpty)
                const Text('No hay horarios disponibles para este día.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              else
                Wrap(spacing: 8, runSpacing: 8, children: _horariosDisponibles.map<Widget>((h) {
                  final hora = h['hora']; final disp = h['disponible'] == true; final seleccionado = _horarioSeleccionado == hora;
                  return ChoiceChip(
                    label: Text(hora, style: TextStyle(color: seleccionado ? Colors.white : (disp ? Colors.black : Colors.grey))), 
                    selected: seleccionado, 
                    selectedColor: const Color(0xFF075BA8), 
                    onSelected: disp ? (v) => _seleccionarHorario(hora) : null
                  );
                }).toList()),
              const SizedBox(height: 20),
            ],

            // PASO 5: CAMILLA
            if (_horarioSeleccionado != null && !_cargandoRecursos) ...[
              const Text('5. Camilla / Equipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 8),
              if (_recursosDisponibles.isEmpty) 
                const Text('No hay camillas disponibles para este horario.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              else 
                Wrap(spacing: 8, runSpacing: 8, children: _recursosDisponibles.map<Widget>((r) {
                  final seleccionado = _recursoSeleccionado == r['nombre'];
                  return ChoiceChip(label: Text(r['nombre'].toString(), style: TextStyle(color: seleccionado ? Colors.white : Colors.black)), selected: seleccionado, selectedColor: const Color(0xFF075BA8), onSelected: (v) => setState(() => _recursoSeleccionado = r['nombre']));
                }).toList()),
              const SizedBox(height: 20),
            ],
            if (_cargandoRecursos) const Center(child: CircularProgressIndicator()),

            if (_error != null) ...[
              const SizedBox(height: 15), 
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            ],
            const SizedBox(height: 30),
            
            SizedBox(
              height: 52, 
              child: FilledButton(
                onPressed: _guardando ? null : _guardar, 
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF075BA8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                child: _guardando ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar Cita', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              )
            ),
          ],
        ),
      ),
    );
  }
}

class _BuscadorModal extends StatefulWidget {
  final String titulo;
  final List<dynamic> items;
  final String Function(Map) textoBusqueda;
  final String Function(Map) textoPrincipal;
  final String Function(Map) textoSecundario;

  const _BuscadorModal({
    required this.titulo,
    required this.items,
    required this.textoBusqueda,
    required this.textoPrincipal,
    required this.textoSecundario,
  });

  @override
  State<_BuscadorModal> createState() => _BuscadorModalState();
}

class _BuscadorModalState extends State<_BuscadorModal> {
  String _filtro = '';

  String _normalizar(String texto) {
    return texto.toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.items.where((i) {
      final map = i as Map;
      final texto = widget.textoBusqueda(map);
      return _normalizar(texto).contains(_normalizar(_filtro));
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true, 
              decoration: InputDecoration(
                hintText: 'Buscar...', 
                prefixIcon: const Icon(Icons.search), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ), 
              onChanged: (v) => setState(() => _filtro = v)
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtrados.isEmpty 
              ? const Center(child: Text('No se encontraron resultados.', style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
                  controller: scrollController, 
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final map = filtrados[i] as Map;
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFE4F1FC), child: Icon(Icons.person, color: Color(0xFF075BA8))),
                      title: Text(widget.textoPrincipal(map), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(widget.textoSecundario(map)),
                      onTap: () => Navigator.pop(context, map),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}