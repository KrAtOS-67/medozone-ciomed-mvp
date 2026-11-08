import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/api_client.dart';

class BillingDetailScreen extends StatefulWidget {
  const BillingDetailScreen({super.key, required this.api, required this.factura});
  final ApiClient api;
  final Map factura;

  @override
  State<BillingDetailScreen> createState() => _BillingDetailScreenState();
}

class _BillingDetailScreenState extends State<BillingDetailScreen> {
  late Future<dynamic> _pagos;
  bool _guardando = false;
  bool _enviandoCorreo = false;

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  void _cargarPagos() {
    _pagos = widget.api.get('/facturas/${widget.factura['id']}/pagos');
  }

  Future<void> _registrarPago() async {
    final montoCtrl = TextEditingController(text: widget.factura['saldo'].toString());
    String metodo = 'EFECTIVO';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Registrar Abono / Cuota'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto a pagar (Bs.)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: metodo,
                  decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo (Caja)')),
                    DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia QR ACH')),
                    DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta de Débito/Crédito')),
                  ],
                  onChanged: (v) => setDialogState(() => metodo = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar')),
            ],
          );
        },
      ),
    );

    if (confirmado != true || !mounted) return;
    
    final monto = double.tryParse(montoCtrl.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _guardando = true);
    try {
      await widget.api.post('/facturas/${widget.factura['id']}/pagos', {'monto': monto, 'metodo': metodo});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abono registrado.'), backgroundColor: Colors.green));
      Navigator.pop(context, true); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _guardando = false); }
  }

  Future<pw.Document> _generarPdf() async {
    final pdf = pw.Document();
    final logoData = await rootBundle.load('assets/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final fecha = DateTime.parse(widget.factura['emitidaEn']).toLocal();
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    final total = (widget.factura['total'] as num).toDouble();
    final pagado = (widget.factura['pagado'] as num).toDouble();
    final saldo = (widget.factura['saldo'] as num).toDouble();
    
    final primaryColor = PdfColor.fromHex('#075BA8');
    final bgColor = PdfColor.fromHex('#E4F1FC');
    final textGrey = PdfColor.fromHex('#546E7A');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(logoImage, height: 60),
                    pw.SizedBox(height: 8),
                    pw.Text('Ozonoterapia · Hiperbárica', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                    pw.SizedBox(height: 4),
                    pw.Text('Clínica CIOMED S.R.L.', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('NIT: 1020304050', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                    pw.Text('Av. Principal #123, La Paz - Bolivia', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                    pw.Text('Teléfono: +591 777 12345', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FACTURA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('N° ${widget.factura['id'].toString().padLeft(6, '0')}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: saldo > 0 ? PdfColors.orange100 : PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        saldo > 0 ? 'PENDIENTE' : 'PAGADA',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: saldo > 0 ? PdfColors.orange800 : PdfColors.green800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: primaryColor, thickness: 2),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(color: bgColor, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DATOS DEL PACIENTE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(widget.factura['paciente'], style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FECHA DE EMISIÓN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(fechaStr, style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1) },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('DESCRIPCIÓN / CONCEPTO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('IMPORTE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(widget.factura['concepto'], style: const pw.TextStyle(fontSize: 12))),
                    pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Bs. ${total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 12, color: textGrey)), pw.Text('Bs. ${total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12))]),
                      pw.SizedBox(height: 5),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Pagado a la fecha:', style: pw.TextStyle(fontSize: 12, color: textGrey)), pw.Text('Bs. ${pagado.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.green700))]),
                      pw.Divider(),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('SALDO PENDIENTE:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), pw.Text('Bs. ${saldo.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: saldo > 0 ? PdfColors.red700 : PdfColors.green700))]),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('áGracias por su preferencia!', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 4),
                  pw.Text('Este documento es un comprobante interno de CIOMED.', style: pw.TextStyle(fontSize: 9, color: textGrey)),
                  pw.Text('Generado por el sistema MedOzone.', style: pw.TextStyle(fontSize: 9, color: textGrey)),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  Future<void> _enviarWhatsApp() async {
    final pdf = await _generarPdf();
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Factura_CIOMED_${widget.factura['id']}.pdf');
  }

  Future<void> _enviarCorreo() async {
    setState(() => _enviandoCorreo = true);
    try {
      final pdf = await _generarPdf();
      final bytes = await pdf.save();
      final base64Pdf = base64Encode(bytes);

      await widget.api.post('/facturas/${widget.factura['id']}/email', {'pdfBase64': base64Pdf});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura enviada a ${widget.factura['email']}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviandoCorreo = false);
    }
  }

  Future<void> _descargarImprimirPdf() async {
    final pdf = await _generarPdf();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Factura_CIOMED_${widget.factura['id']}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.factura['total'] as num).toDouble();
    final pagado = (widget.factura['pagado'] as num).toDouble();
    final saldo = (widget.factura['saldo'] as num).toDouble();
    final esPendiente = saldo > 0;
    
    final tieneWhatsApp = widget.factura['telefono'] != null && widget.factura['telefono'].toString().isNotEmpty;
    final tieneCorreo = widget.factura['email'] != null && widget.factura['email'].toString().isNotEmpty;
    
    final fecha = DateTime.parse(widget.factura['emitidaEn']).toLocal();
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(title: const Text('Detalle de Factura'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Factura #${widget.factura['id'].toString().padLeft(6, '0')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: esPendiente ? Colors.orange.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text(esPendiente ? 'PENDIENTE' : 'PAGADA', style: TextStyle(color: esPendiente ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Paciente: ${widget.factura['paciente']}', style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    Text('Fecha: $fechaStr', style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                    const SizedBox(height: 16),
                    Text(widget.factura['concepto'], style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          _filaMonto('Total Factura:', 'Bs. ${total.toStringAsFixed(2)}', Colors.black),
                          const SizedBox(height: 8),
                          _filaMonto('Total Pagado:', 'Bs. ${pagado.toStringAsFixed(2)}', Colors.green),
                          const Divider(),
                          _filaMonto('SALDO PENDIENTE:', 'Bs. ${saldo.toStringAsFixed(2)}', esPendiente ? Colors.red : Colors.green, isBold: true, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Align(alignment: Alignment.centerLeft, child: Text('Historial de Pagos / Cuotas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)))),
            const SizedBox(height: 8),
            FutureBuilder<dynamic>(
              future: _pagos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                final lista = snapshot.data as List? ?? [];
                if (lista.isEmpty) return const Text('No se han registrado pagos aún.', style: TextStyle(color: Colors.grey));

                return ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final p = lista[index] as Map;
                    final fechaPago = DateTime.parse(p['fecha']).toLocal();
                    final fStr = '${fechaPago.day}/${fechaPago.month}/${fechaPago.year} ${fechaPago.hour}:${fechaPago.minute.toString().padLeft(2, '0')}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Abono: Bs. ${p['monto']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$fStr - ${p['metodo']}\nCobrado por: ${p['registradoPor']}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      
      // BOTONERA INFERIOR DINÁMICA
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 1. BOTÓN DE DESCARGAR PDF (SIEMPRE VISIBLE, SIN RESTRICCIONES)
              Expanded(
                flex: (esPendiente || tieneCorreo || tieneWhatsApp) ? 1 : 2,
                child: OutlinedButton(
                  onPressed: _descargarImprimirPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF075BA8),
                    side: const BorderSide(color: Color(0xFF075BA8)),
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 22),
                      // Si es el único botón, mostramos texto
                      if (!esPendiente && !tieneCorreo && !tieneWhatsApp) ...[
                        const SizedBox(height: 2),
                        const Text('Descargar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ] else if (esPendiente) ...[
                        const SizedBox(height: 2),
                        const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                ),
              ),

              // Si hay más botones, añadimos un espacio
              if (esPendiente || tieneCorreo || tieneWhatsApp) const SizedBox(width: 8),

              // 2. SI FALTA PAGAR -> BOTÓN COBRAR
              if (esPendiente)
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _registrarPago,
                    icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.payment),
                    label: const Text('Abonar / Pagar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF075BA8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(0, 52)),
                  ),
                )
              // 3. SI YA PAGÓ -> BOTONES DE ENVÍO
              else ...[
                if (tieneCorreo)
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _enviandoCorreo ? null : _enviarCorreo,
                      icon: _enviandoCorreo ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.email, size: 20),
                      label: Text(_enviandoCorreo ? '...' : 'Correo', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (tieneCorreo && tieneWhatsApp) const SizedBox(width: 8),
                if (tieneWhatsApp)
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _enviarWhatsApp,
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaMonto(String label, String value, Color color, {bool isBold = false, double size = 15}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: size)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color)),
      ],
    );
  }
}