import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../core/api_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _inicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fin = DateTime.now();
  bool _cargando = false;
  String? _error;
  
  // Datos para los reportes
  Map<String, dynamic>? _datos;
  List<dynamic> _deudas = [];
  List<dynamic> _usuarios = [];
  List<dynamic> _pacientes = [];
  List<dynamic> _sesiones = [];
  
  bool _exportando = false;

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtDisplay(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final f = await showDatePicker(
        context: context,
        initialDate: esInicio ? _inicio : _fin,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (f == null || !mounted) return;
    setState(() {
      if (esInicio) _inicio = f; else _fin = f;
    });
    _consultar();
  }

  Future<void> _consultar() async {
    setState(() { _cargando = true; _error = null; _datos = null; });
    try {
      final results = await Future.wait([
        widget.api.get('/reportes/estadisticas?inicio=${_fmt(_inicio)}&fin=${_fmt(_fin)}'),
        widget.api.get('/reportes/deudas'),
        widget.api.get('/reportes/usuarios'),
        widget.api.get('/reportes/pacientes'),
        widget.api.get('/reportes/sesiones'),
      ]);
      if (!mounted) return;
      setState(() {
        _datos = results[0] as Map<String, dynamic>;
        _deudas = results[1] as List;
        _usuarios = results[2] as List;
        _pacientes = results[3] as List;
        _sesiones = results[4] as List;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // =====================================================================
  // EXPORTAR A EXCEL (6 HOJAS)
  // =====================================================================
  Future<void> _exportarExcel() async {
    if (_datos == null) return;
    setState(() => _exportando = true);
    try {
      final excel = Excel.createExcel();
      final titleStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.white, backgroundColorHex: ExcelColor.fromHexString('#075BA8'));
      final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#E4F1FC'));

      // Hoja 1: FINANZAS
      final sheetFinanzas = excel['Finanzas'];
      final ingresos = _datos!['ingresos'] as Map;
      sheetFinanzas.appendRow([TextCellValue('CIOMED - Reporte Financiero')]);
      sheetFinanzas.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
      sheetFinanzas.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetFinanzas.appendRow([TextCellValue('Período:'), TextCellValue('${_fmtDisplay(_inicio)} al ${_fmtDisplay(_fin)}')]);
      sheetFinanzas.appendRow([]);
      sheetFinanzas.appendRow([TextCellValue('Total Recaudado'), DoubleCellValue((ingresos['pagados'] as num).toDouble())]);
      sheetFinanzas.appendRow([TextCellValue('Saldo Pendiente'), DoubleCellValue((ingresos['pendientes'] as num).toDouble())]);
      sheetFinanzas.appendRow([]);
      sheetFinanzas.appendRow([TextCellValue('FLUJO DIARIO'), TextCellValue('MONTO')]);
      sheetFinanzas.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 7)).cellStyle = headerStyle;
      sheetFinanzas.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7)).cellStyle = headerStyle;
      for (var d in (ingresos['diarios'] as List)) {
        sheetFinanzas.appendRow([TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.parse(d['fecha'].toString()))), DoubleCellValue((d['total'] as num).toDouble())]);
      }

      // Hoja 2: RANKING PERSONAL
      final sheetRanking = excel['Ranking'];
      sheetRanking.appendRow([TextCellValue('CIOMED - Ranking de Personal (Solo Activos)')]);
      sheetRanking.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0));
      sheetRanking.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetRanking.appendRow([TextCellValue('POSICIÓN'), TextCellValue('PROFESIONAL'), TextCellValue('SESIONES')]);
      for (int i = 0; i < 3; i++) sheetRanking.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2)).cellStyle = headerStyle;
      final List ranking = _datos!['rankingProfesionales'] ?? [];
      for (var i = 0; i < ranking.length; i++) {
        sheetRanking.appendRow([IntCellValue(i + 1), TextCellValue(ranking[i]['profesional'].toString()), IntCellValue((ranking[i]['total'] as num).toInt())]);
      }

      // Hoja 3: DEUDAS
      final sheetDeudas = excel['Deudas'];
      sheetDeudas.appendRow([TextCellValue('CIOMED - Cuentas por Cobrar')]);
      sheetDeudas.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0));
      sheetDeudas.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetDeudas.appendRow([TextCellValue('PACIENTE'), TextCellValue('TELÉFONO'), TextCellValue('TOTAL (Bs.)'), TextCellValue('PAGADO (Bs.)'), TextCellValue('SALDO (Bs.)')]);
      for (int i = 0; i < 5; i++) sheetDeudas.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2)).cellStyle = headerStyle;
      for (var d in _deudas) {
        sheetDeudas.appendRow([TextCellValue(d['paciente'].toString()), TextCellValue(d['telefono']?.toString() ?? 'S/N'), DoubleCellValue((d['total'] as num).toDouble()), DoubleCellValue((d['pagado'] as num).toDouble()), DoubleCellValue((d['saldo'] as num).toDouble())]);
      }

      // Hoja 4: DIRECTORIO DE PERSONAL
      final sheetStaff = excel['Personal'];
      sheetStaff.appendRow([TextCellValue('CIOMED - Directorio de Personal')]);
      sheetStaff.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0));
      sheetStaff.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetStaff.appendRow([TextCellValue('USUARIO'), TextCellValue('NOMBRE'), TextCellValue('ROL'), TextCellValue('EMAIL'), TextCellValue('TELÉFONO'), TextCellValue('ESTADO'), TextCellValue('ÁREAS')]);
      for (int i = 0; i < 7; i++) sheetStaff.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2)).cellStyle = headerStyle;
      for (var u in _usuarios) {
        sheetStaff.appendRow([TextCellValue(u['username'].toString()), TextCellValue(u['full_name'].toString()), TextCellValue(u['role'].toString()), TextCellValue(u['email']?.toString() ?? 'N/A'), TextCellValue(u['telefono']?.toString() ?? 'N/A'), TextCellValue(u['estado'].toString()), TextCellValue(u['areas'].toString())]);
      }

      // Hoja 5: DIRECTORIO DE PACIENTES
      final sheetPacientes = excel['Pacientes'];
      sheetPacientes.appendRow([TextCellValue('CIOMED - Directorio de Pacientes')]);
      sheetPacientes.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));
      sheetPacientes.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetPacientes.appendRow([TextCellValue('NOMBRES'), TextCellValue('APELLIDOS'), TextCellValue('DOCUMENTO'), TextCellValue('TELÉFONO'), TextCellValue('ESTADO CLÍNICO'), TextCellValue('ESTADO')]);
      for (int i = 0; i < 6; i++) sheetPacientes.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2)).cellStyle = headerStyle;
      for (var p in _pacientes) {
        sheetPacientes.appendRow([TextCellValue(p['nombres'].toString()), TextCellValue(p['apellidos'].toString()), TextCellValue(p['documento']?.toString() ?? 'S/N'), TextCellValue(p['telefono']?.toString() ?? 'S/N'), TextCellValue(p['estado_clinico'].toString()), TextCellValue(p['estado'].toString())]);
      }

      // Hoja 6: HISTORIAL DE ATENCIÓN
      final sheetHistorial = excel['Historial'];
      sheetHistorial.appendRow([TextCellValue('CIOMED - Historial de Atención')]);
      sheetHistorial.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0));
      sheetHistorial.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheetHistorial.appendRow([TextCellValue('PACIENTE'), TextCellValue('TRATAMIENTO'), TextCellValue('FECHA'), TextCellValue('DOSIS'), TextCellValue('PRESIÓN'), TextCellValue('TEMP'), TextCellValue('F.C.'), TextCellValue('SpO2'), TextCellValue('REGISTRADO POR'), TextCellValue('ESTADO')]);
      for (int i = 0; i < 10; i++) sheetHistorial.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2)).cellStyle = headerStyle;
      for (var s in _sesiones) {
        sheetHistorial.appendRow([TextCellValue(s['paciente'].toString()), TextCellValue(s['tipo_tratamiento'].toString().replaceAll('_', ' ')), TextCellValue(s['fecha'].toString()), TextCellValue(s['dosis']?.toString() ?? '-'), TextCellValue(s['presion']?.toString() ?? '-'), TextCellValue(s['temperatura']?.toString() ?? '-'), TextCellValue(s['frecuencia_cardiaca']?.toString() ?? '-'), TextCellValue(s['saturacion_oxigeno']?.toString() ?? '-'), TextCellValue(s['registrado_por'].toString()), TextCellValue(s['estado'].toString())]);
      }

      // GUARDAR Y COMPARTIR
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/Reporte_CIOMED_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes, flush: true);
        final params = ShareParams(files: [XFile(filePath)], text: 'Reporte Gerencial CIOMED');
        await SharePlus.instance.share(params);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar Excel: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // =====================================================================
  // EXPORTAR A PDF
  // =====================================================================
  Future<void> _exportarPdf() async {
    if (_datos == null) return;
    setState(() => _exportando = true);
    try {
      final pdf = pw.Document();
      final logoData = await rootBundle.load('assets/logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      final primaryColor = PdfColor.fromHex('#075BA8');
      
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Image(logoImage, height: 60),
              pw.SizedBox(height: 8),
              pw.Text('Clínica CIOMED S.R.L.', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Reporte Gerencial Completo', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('PERIODO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Text('${_fmtDisplay(_inicio)} al ${_fmtDisplay(_fin)}', style: pw.TextStyle(fontSize: 12)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.Divider(color: primaryColor, thickness: 2),
          pw.SizedBox(height: 20),
          
          pw.Text('1. Resumen Financiero', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Recaudado:'), pw.Text('Bs. ${(_datos!['ingresos']['pagados'] as num).toStringAsFixed(2)}')]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Saldo Pendiente:'), pw.Text('Bs. ${(_datos!['ingresos']['pendientes'] as num).toStringAsFixed(2)}')]),
          pw.SizedBox(height: 20),
          
          pw.Text('2. Directorio de Personal', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: ['USUARIO', 'NOMBRE', 'ROL', 'ESTADO'],
            data: _usuarios.map((u) => [u['username'].toString(), u['full_name'].toString(), u['role'].toString(), u['estado'].toString()]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),

          pw.Text('3. Directorio de Pacientes', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: ['NOMBRE', 'DOCUMENTO', 'TELÉFONO', 'ESTADO'],
            data: _pacientes.map((p) => ['${p['nombres']} ${p['apellidos']}', p['documento']?.toString() ?? 'S/N', p['telefono']?.toString() ?? 'S/N', p['estado'].toString()]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Reporte_CIOMED.pdf');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // =====================================================================
  // MENÚ DE EXPORTACIÓN
  // =====================================================================
  void _mostrarMenuExportar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Exportar Reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: const Text('Descargar / Imprimir PDF'), onTap: () { Navigator.pop(ctx); _exportarPdf(); }),
            ListTile(leading: const Icon(Icons.table_chart, color: Colors.green), title: const Text('Descargar Excel (.xlsx)'), onTap: () { Navigator.pop(ctx); _exportarExcel(); }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // UI PRINCIPAL (Pestañas y Tarjetas)
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          title: const Text('Dashboard Gerencial'),
          backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0,
          actions: [
            if (_datos != null)
              IconButton(
                icon: _exportando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF075BA8))) : const Icon(Icons.ios_share, color: Color(0xFF075BA8)),
                onPressed: _exportando ? null : _mostrarMenuExportar,
                tooltip: 'Exportar Reporte',
              ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF075BA8), unselectedLabelColor: Colors.grey, indicatorColor: Color(0xFF075BA8),
            tabs: [Tab(text: 'Finanzas', icon: Icon(Icons.attach_money)), Tab(text: 'Personal', icon: Icon(Icons.people)), Tab(text: 'Deudas', icon: Icon(Icons.money_off))],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _seleccionarFecha(true), icon: const Icon(Icons.calendar_today, size: 16), label: Text(_fmtDisplay(_inicio)))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('al')),
                Expanded(child: OutlinedButton.icon(onPressed: () => _seleccionarFecha(false), icon: const Icon(Icons.calendar_today, size: 16), label: Text(_fmtDisplay(_fin)))),
              ]),
            ),
            Expanded(
              child: _cargando ? const Center(child: CircularProgressIndicator())
                  : _error != null ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                  : _datos == null ? const SizedBox()
                  : TabBarView(children: [_buildTabFinanzas(), _buildTabPersonal(), _buildTabDeudas()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabFinanzas() {
    final ingresos = _datos!['ingresos'] as Map;
    final List diarios = ingresos['diarios'] ?? [];
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      _cardTotalIngresos(ingresos),
      const SizedBox(height: 12),
      _cardIngresosDiarios(diarios),
      const SizedBox(height: 12),
      _cardPacientesPorTratamiento(),
    ]);
  }

  Widget _buildTabPersonal() {
    final List ranking = _datos!['rankingProfesionales'] ?? [];
    final List pacientesHoy = _datos!['pacientesHoy'] ?? [];
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      _cardRankingPersonal(ranking),
      const SizedBox(height: 12),
      _cardCumplimiento(),
      const SizedBox(height: 12),
      _cardPacientesHoy(pacientesHoy),
    ]);
  }

  Widget _buildTabDeudas() {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.money_off, color: Colors.red), SizedBox(width: 8), Text('Cuentas por Cobrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          const Divider(),
          if (_deudas.isEmpty) const Text('No hay deudas pendientes.', style: TextStyle(color: Colors.grey)),
          ..._deudas.map((d) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person, color: Colors.white, size: 18)),
            title: Text(d['paciente'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Total: Bs. ${d['total']} | Pagado: Bs. ${d['pagado']}'),
            trailing: Text('Bs. ${(d['saldo'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
            isThreeLine: true,
          )),
        ])),
      ),
    ]);
  }

  Widget _cardTotalIngresos(Map ingresos) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: const Color(0xFF075BA8),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total Recaudado', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text('Bs. ${(ingresos['pagados'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Saldo pendiente: Bs. ${(ingresos['pendientes'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    );
  }

  Widget _cardIngresosDiarios(List diarios) {
    return Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Flujo de Caja Diario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        if (diarios.isEmpty) const Text('No hay ingresos.', style: TextStyle(color: Colors.grey)),
        ...diarios.map((d) {
          final fecha = DateTime.parse(d['fecha'].toString());
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('dd/MM/yyyy').format(fecha)),
            Text('Bs. ${(d['total'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ]));
        }),
      ])),
    );
  }

  Widget _cardRankingPersonal(List ranking) {
    return Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.emoji_events, color: Colors.orange), SizedBox(width: 8), Text('Ranking de Personal (Activos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const Divider(),
        if (ranking.isEmpty) const Text('Sin datos.', style: TextStyle(color: Colors.grey)),
        ...ranking.asMap().entries.map((entry) {
          final i = entry.key; final r = entry.value;
          return ListTile(dense: true, contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: i == 0 ? Colors.amber : (i == 1 ? Colors.grey.shade300 : Colors.brown.shade200), child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
            title: Text(r['profesional'].toString()), trailing: Text('${r['total']} sesiones', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF075BA8))));
        }),
      ])),
    );
  }

  Widget _cardPacientesHoy(List pacientes) {
    return Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.calendar_today, color: Color(0xFF075BA8)), SizedBox(width: 8), Text('Agenda de Hoy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
        const Divider(),
        if (pacientes.isEmpty) const Text('Sin pacientes hoy.', style: TextStyle(color: Colors.grey)),
        ...pacientes.map((p) {
          final hora = DateTime.parse(p['inicio'].toString()).toLocal();
          return ListTile(dense: true, contentPadding: EdgeInsets.zero,
            leading: Icon(p['estado'] == 'ATENDIDA' ? Icons.check_circle : Icons.access_time, color: p['estado'] == 'ATENDIDA' ? Colors.green : Colors.orange),
            title: Text(p['paciente'].toString()), subtitle: Text(p['profesional'].toString()), trailing: Text(DateFormat('HH:mm').format(hora), style: const TextStyle(fontWeight: FontWeight.bold)));
        }),
      ])),
    );
  }

  Widget _cardPacientesPorTratamiento() {
    final List items = _datos!['pacientesPorTratamiento'] ?? [];
    return Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pacientes por Tratamiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        ...items.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text((e['tipo'] ?? '').toString().replaceAll('_', ' ')),
          Text('${e['cantidad']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF075BA8))),
        ]))),
        if (items.isEmpty) const Text('Sin datos.', style: TextStyle(color: Colors.grey)),
      ])),
    );
  }

  Widget _cardCumplimiento() {
    final c = _datos!['cumplimiento'] as Map;
    final atendidas = c['atendidas'] as int; final ausentes = c['ausentes'] as int; final canceladas = c['canceladas'] as int;
    final total = atendidas + ausentes + canceladas;
    final pct = total == 0 ? 0 : (atendidas / total * 100).round();
    return Card(elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cumplimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Tasa de Asistencia:'), Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: pct >= 80 ? Colors.green : Colors.orange))
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: total == 0 ? 0 : atendidas / total, backgroundColor: Colors.grey.shade200, color: Colors.green, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 12),
        _filaMonto('Atendidas:', '$atendidas', Colors.green),
        _filaMonto('Ausentes:', '$ausentes', Colors.orange),
        _filaMonto('Canceladas:', '$canceladas', Colors.red),
      ])),
    );
  }

  Widget _filaMonto(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.black87)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color))
    ]));
  }
}