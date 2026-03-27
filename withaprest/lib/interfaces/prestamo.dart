import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:withaprest/models/prestamo_model.dart';
import 'package:withaprest/models/registro_model.dart';
import 'package:withaprest/services/prestamo_services.dart';
import 'package:withaprest/theme/iniciotema.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class Prestamo extends StatefulWidget {
  final ClienteRow cliente;
  const Prestamo({super.key, required this.cliente});

  @override
  State<Prestamo> createState() => _PrestamoState();
}

class _PrestamoState extends State<Prestamo> {
  final _svc = PrestamoService();

  bool _loading = true;
  String? _error;

  PrestamoRow? _prestamoActivo;
  List<AvalRow> _avales = [];
  final Set<String> _avalIds = {};

  final _montoCtrl = TextEditingController();

  FrecuenciaPrestamo _frecuencia = FrecuenciaPrestamo.semanal;
  DateTime? _primerPago;

  bool _creando = false;

  TipoPrestamo get _tipo =>
      (_prestamoActivo == null) ? TipoPrestamo.nuevo : TipoPrestamo.renovacion;

  int get _numeroCuotasFijas {
    switch (_frecuencia) {
      case FrecuenciaPrestamo.semanal:
        return 14;
      case FrecuenciaPrestamo.quincenal:
        return 7;
      case FrecuenciaPrestamo.mensual:
        return 4;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final activo = await _svc.getPrestamoActivoCliente(widget.cliente.id);
      final avales = await _svc.listarAvalesCliente(widget.cliente.id);

      if (!mounted) return;
      setState(() {
        _prestamoActivo = activo;
        _avales = avales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _montoSolicitado() {
    final raw = _montoCtrl.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (_loading) return const _LoadingBoxPrestamo();
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _ErrorBoxPrestamo(mensaje: _error!, onRetry: _load),
      );
    }

    final double monto = _montoSolicitado();
    final int cuotas = _numeroCuotasFijas;

    final double montoContrato = monto * 2.0;
    double round2(double v) => (v * 100).round() / 100.0;

    // OJO:
    // cuota real en BD = monto real / cuotas
    final double montoCuotaReal = (monto > 0 && cuotas > 0)
        ? round2(monto / cuotas)
        : 0.0;

    // cuota mostrada en contrato = monto contrato / cuotas
    final double montoCuotaContrato = (montoContrato > 0 && cuotas > 0)
        ? round2(montoContrato / cuotas)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ClienteCardPrestamo(
          cliente: widget.cliente,
          prestamoActivo: _prestamoActivo,
        ),
        const SizedBox(height: 14),

        const _SectionTitle(
          icon: Icons.verified_user_outlined,
          title: 'Avales para el documento',
        ),
        const SizedBox(height: 8),

        _avales.isEmpty
            ? const _HintBox(
                text:
                    'Este cliente no tiene avales registrados. '
                    'El documento saldrá sin avales.',
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _avales.map((a) {
                  final selected = _avalIds.contains(a.id);
                  return FilterChip(
                    selected: selected,
                    label: Text(a.nombreCompleto, style: t.bodyLarge),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _avalIds.add(a.id);
                        } else {
                          _avalIds.remove(a.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

        const SizedBox(height: 18),
        const _SectionTitle(
          icon: Icons.payments_outlined,
          title: 'Datos del préstamo',
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto solicitado',
            hintText: 'Ej. 15000',
            prefixIcon: Icon(Icons.attach_money),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<FrecuenciaPrestamo>(
          initialValue: _frecuencia,
          decoration: const InputDecoration(
            labelText: 'Frecuencia',
            prefixIcon: Icon(Icons.repeat),
          ),
          items: FrecuenciaPrestamo.values.map((f) {
            return DropdownMenuItem(
              value: f,
              child: Text(f.name, style: t.bodyLarge),
            );
          }).toList(),
          onChanged: (v) => setState(() => _frecuencia = v ?? _frecuencia),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Número de cuotas: $cuotas', style: t.bodyLarge),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _DatePickerTile(
          title: 'Fecha del primer pago',
          value: _primerPago,
          onPick: (d) => setState(() => _primerPago = d),
        ),

        const SizedBox(height: 16),
        _ResumenCard(
          montoSolicitado: monto,
          montoContrato: montoContrato,
          cuotas: cuotas,
          montoCuotaReal: montoCuotaReal,
          montoCuotaContrato: montoCuotaContrato,
        ),

        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _creando
              ? null
              : () => _generar(
                  montoSolicitado: monto,
                  cuotas: cuotas,
                  fechaPrimerPago: _primerPago,
                ),
          icon: _creando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.description_outlined),
          label: Text(
            _tipo == TipoPrestamo.nuevo
                ? 'Generar contrato'
                : 'Generar renovación',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(height: 10),
        Text(
          'En base de datos se guarda el monto real. El doble solo vive en el contrato, como villano de novela.',
          style: t.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _generar({
    required double montoSolicitado,
    required int cuotas,
    required DateTime? fechaPrimerPago,
  }) async {
    if (montoSolicitado <= 0) return _toast('Escribe un monto válido.');
    if (cuotas <= 0) return _toast('Número de cuotas inválido.');
    if (fechaPrimerPago == null) {
      return _toast('Selecciona la fecha del primer pago.');
    }

    setState(() => _creando = true);
    try {
      final prestamo = await _svc.crearPrestamoConCuotas(
        cliente: widget.cliente,
        montoSolicitado: montoSolicitado,
        numeroCuotas: cuotas,
        frecuencia: _frecuencia,
        fechaPrimerPago: fechaPrimerPago,
        prestamoActivoAnterior: _prestamoActivo,
        liquidarAnterior: false,
      );

      final avalesSeleccionados = _avales
          .where((a) => _avalIds.contains(a.id))
          .toList();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContratoPdfPage(
            cliente: widget.cliente,
            prestamo: prestamo,
            avales: avalesSeleccionados,
            montoSolicitado: montoSolicitado,
          ),
        ),
      );
    } catch (e) {
      _toast('No se pudo generar: $e');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ----------------- Widgets auxiliares estilo ClientesPage -----------------

class _LoadingBoxPrestamo extends StatelessWidget {
  const _LoadingBoxPrestamo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(18),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(height: 12),
              Text('Cargando préstamo...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBoxPrestamo extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;
  const _ErrorBoxPrestamo({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ups…',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(mensaje, style: t.bodyMedium?.copyWith(color: Colors.redAccent)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// Reusa tus widgets existentes (puedes dejarlos igual o moverlos a un archivo común):
// _ClienteCardPrestamo, _SectionTitle, _DatePickerTile, _ResumenCard, _HintBox, ContratoPreviewPage

// ---------------- Widgets ----------------

class _ClienteCardPrestamo extends StatelessWidget {
  final ClienteRow cliente;
  final PrestamoRow? prestamoActivo;

  const _ClienteCardPrestamo({
    required this.cliente,
    required this.prestamoActivo,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cliente.codigo} • ${cliente.nombreCompleto}',
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.text1,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18, color: AppTheme.text2),
              const SizedBox(width: 8),
              Text(
                'Avales: ${cliente.avalesCount}',
                style: t.bodyMedium?.copyWith(color: AppTheme.text2),
              ),
            ],
          ),

          if (prestamoActivo != null) ...[
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tiene préstamo activo (${prestamoActivo!.frecuencia.name}). '
                      'Se generará como renovación.',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClienteCard extends StatelessWidget {
  final ClienteRow cliente;
  final PrestamoRow? prestamoActivo;

  const _ClienteCard({required this.cliente, required this.prestamoActivo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cliente.codigo} • ${cliente.nombreCompleto}',
            style: t.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18, color: AppTheme.text2),
              const SizedBox(width: 8),
              Text('Avales: ${cliente.avalesCount}', style: t.bodyLarge),
            ],
          ),
          if (prestamoActivo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tiene préstamo activo (${prestamoActivo!.frecuencia.name}). '
                      'Se generará como renovación.',
                      style: t.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: AppTheme.text2),
        const SizedBox(width: 10),
        Text(title, style: t.titleMedium),
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String title;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  const _DatePickerTile({
    required this.title,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final df = DateFormat('yyyy-MM-dd');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
          builder: (context, child) =>
              Theme(data: AppTheme.theme(), child: child!),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Seleccionar fecha' : df.format(value!),
                    style: t.bodyLarge,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final double montoSolicitado;
  final double montoContrato;
  final int cuotas;
  final double montoCuotaReal;
  final double montoCuotaContrato;

  const _ResumenCard({
    required this.montoSolicitado,
    required this.montoContrato,
    required this.cuotas,
    required this.montoCuotaReal,
    required this.montoCuotaContrato,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: t.titleMedium),
          const SizedBox(height: 10),
          _row(t, 'Monto real (BD)', money.format(montoSolicitado)),
          const SizedBox(height: 6),
          _row(t, 'Monto contrato (x2)', money.format(montoContrato)),
          const SizedBox(height: 6),
          _row(t, 'Cuotas', '$cuotas'),
          const SizedBox(height: 6),
          _row(t, 'Cuota real (BD)', money.format(montoCuotaReal)),
          const SizedBox(height: 6),
          _row(t, 'Cuota contrato', money.format(montoCuotaContrato)),
        ],
      ),
    );
  }

  Widget _row(TextTheme t, String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: t.bodyMedium)),
        Text(v, style: t.bodyLarge),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  final String text;
  const _HintBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t.bodyLarge)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;
  const _ErrorBox({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Algo tronó', style: t.titleLarge),
          const SizedBox(height: 8),
          Text(mensaje, style: t.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

//==========Generador de contrato ===========
class ContratoPdfPage extends StatelessWidget {
  final ClienteRow cliente;
  final PrestamoRow prestamo;
  final List<AvalRow> avales;
  final double montoSolicitado;

  const ContratoPdfPage({
    super.key,
    required this.cliente,
    required this.prestamo,
    required this.avales,
    required this.montoSolicitado,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrato PDF')),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'contrato_${cliente.codigo}.pdf',
        build: (format) => ContratoPdfGenerator.generar(
          format: format,
          cliente: cliente,
          prestamo: prestamo,
          avales: avales,
          montoSolicitado: montoSolicitado,
        ),
      ),
    );
  }
}

//==========FORMATO DEL CONTRATO===============
class ContratoPdfGenerator {
  static Future<Uint8List> generar({
    required PdfPageFormat format,
    required ClienteRow cliente,
    required PrestamoRow prestamo,
    required List<AvalRow> avales,
    required double montoSolicitado,
  }) async {
    final pdf = pw.Document();

    final montoContrato = montoSolicitado * 2.0;
    final montoTexto = NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 2,
    ).format(montoContrato);

    final montoLetra =
        '${_numeroALetras(montoContrato.toInt()).toUpperCase()} PESOS 00/100 MONEDA NACIONAL';

    final aval = avales.isNotEmpty ? avales.first : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(46, 26, 46, 26),
        build: (_) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'PAGARE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'SERIE 1/1',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 28),
                    child: pw.Text(
                      'Por el presente PAGARE declaro y me obligo a pagar INCONDICIONALMENTE a la orden de Raul Avila Rodriguez, '
                      'la cantidad de $montoTexto ($montoLetra) en el municipio de TEPIC, NAYARIT.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 8.8, lineSpacing: 2),
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 28),
                    child: pw.Text(
                      'El suscrito se obliga a cubrir la cantidad señalada más sus accesorios financieros en el día '
                      '${_fechaCompleta(prestamo.fechaPrimerVencimiento)}.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 8.8, lineSpacing: 2),
                    ),
                  ),

                  pw.SizedBox(height: 18),

                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 28),
                    child: pw.Text(
                      'Este pagare forma parte de una serie numerada del 1 al 1, y todos están sujetos a la condición '
                      'de que, al no pagarse cualquiera de ellos a su vencimiento, serán exigibles todos los que le sigan '
                      'en número, además de los vencidos, desde la fecha de vencimiento de este documento hasta el día de '
                      'su liquidación, es pagadero los intereses conjuntamente con la suerte principal en esta ciudad.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 8.8, lineSpacing: 2),
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 28),
                    child: pw.Text(
                      'Por caso de mora, las partes pactan que, a partir del vencimiento del pago correspondiente, este '
                      'generara un interés moratorio a razón del 4% (cuatro) por ciento MENSUAL, mismo que se calculara '
                      'durante el tiempo que permanezca insoluto, sin incluir gastos de cobranza extrajudicial y judicial.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 8.8, lineSpacing: 2),
                    ),
                  ),

                  pw.SizedBox(height: 22),

                  pw.Text(
                    'TEPIC, NAYARIT; A ${_fechaMayus(prestamo.fechaInicio)}',
                    style: pw.TextStyle(
                      fontSize: 8.6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'FIRMA DEL ACEPTANTE U OBLIGADO PRINCIPAL',
                    style: pw.TextStyle(
                      fontSize: 8.6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 34),

                  pw.Text(
                    cliente.nombreCompleto.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'CREDENCIAL DEL IFE; ${_nvl(cliente.claveElector).toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 8.4),
                  ),
                  pw.Text(
                    'DOMICILIO; ${_domicilioCliente(cliente).toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 8.4),
                  ),
                  pw.Text(
                    _coloniaCiudadCliente(cliente).toUpperCase(),
                    style: const pw.TextStyle(fontSize: 8.4),
                  ),
                ],
              ),

              if (aval != null)
                pw.Positioned(
                  right: 0,
                  bottom: 18,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'AVAL',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: 205,
                        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.8),
                          borderRadius: pw.BorderRadius.circular(16),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              aval.nombreCompleto.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 8.8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'CREDENCIAL DEL IFE; ${_nvl(aval.claveElector).toUpperCase()}',
                              style: const pw.TextStyle(fontSize: 8.2),
                            ),
                            pw.Text(
                              'DOMICILIO; ${_domicilioAval(aval).toUpperCase()}',
                              style: const pw.TextStyle(fontSize: 8.2),
                            ),
                            pw.Text(
                              _coloniaCiudadAval(aval).toUpperCase(),
                              style: const pw.TextStyle(fontSize: 8.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _nvl(String? v) {
    final txt = (v ?? '').trim();
    return txt.isEmpty ? '________________' : txt;
  }

  static String _domicilioCliente(ClienteRow c) {
    final tipo = _tipoVialidadTexto(c.vialidadTipo);
    final nombre = (c.vialidadNombre ?? '').trim();
    if (tipo.isEmpty && nombre.isEmpty) return '________________';
    return '$tipo $nombre'.trim();
  }

  static String _domicilioAval(AvalRow a) {
    final tipo = _tipoVialidadTexto(a.vialidadTipo);
    final nombre = (a.vialidadNombre ?? '').trim();
    if (tipo.isEmpty && nombre.isEmpty) return '________________';
    return '$tipo $nombre'.trim();
  }

  static String _coloniaCiudadCliente(ClienteRow c) {
    final asentamientoTipo = _tipoAsentamientoTexto(c.asentamientoTipo);
    final asentamientoNombre = (c.asentamientoNombre ?? '').trim();
    final ciudad = (c.ciudad ?? 'Tepic').trim();
    final estado = (c.estado ?? 'Nayarit').trim();

    final parte1 = [
      asentamientoTipo,
      asentamientoNombre,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    if (parte1.isEmpty) return '$ciudad, $estado';
    return '$parte1, $ciudad, $estado';
  }

  static String _coloniaCiudadAval(AvalRow a) {
    final asentamientoTipo = _tipoAsentamientoTexto(a.asentamientoTipo);
    final asentamientoNombre = (a.asentamientoNombre ?? '').trim();
    final ciudad = (a.ciudad ?? 'Tepic').trim();
    final estado = (a.estado ?? 'Nayarit').trim();

    final parte1 = [
      asentamientoTipo,
      asentamientoNombre,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    if (parte1.isEmpty) return '$ciudad, $estado';
    return '$parte1, $ciudad, $estado';
  }

  static String _tipoVialidadTexto(TipoVialidad? t) {
    switch (t) {
      case TipoVialidad.calle:
        return 'CALLE';
      case TipoVialidad.circuito:
        return 'CIRCUITO';
      case TipoVialidad.privada:
        return 'PRIVADA';
      case null:
        return '';
    }
  }

  static String _tipoAsentamientoTexto(TipoAsentamiento? t) {
    switch (t) {
      case TipoAsentamiento.colonia:
        return 'COLONIA';
      case TipoAsentamiento.fraccionamiento:
        return 'FRACCIONAMIENTO';
      case null:
        return '';
    }
  }

  static String _fechaCompleta(DateTime fecha) {
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return '${fecha.day} (${_numeroALetras(fecha.day)}) de ${meses[fecha.month]} del ${fecha.year} (${_numeroALetras(fecha.year)})';
  }

  static String _fechaMayus(DateTime fecha) {
    const meses = [
      '',
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];

    return '${fecha.day} DE ${meses[fecha.month]} DEL ${fecha.year}';
  }

  static String _numeroALetras(int numero) {
    if (numero == 0) return 'cero';
    if (numero < 0) return 'menos ${_numeroALetras(numero.abs())}';
    if (numero <= 29) return _unidades(numero);
    if (numero < 100) return _decenas(numero);
    if (numero < 1000) return _centenas(numero);
    if (numero < 1000000) return _miles(numero);
    if (numero < 1000000000) return _millones(numero);
    return numero.toString();
  }

  static String _unidades(int n) {
    const mapa = {
      1: 'uno',
      2: 'dos',
      3: 'tres',
      4: 'cuatro',
      5: 'cinco',
      6: 'seis',
      7: 'siete',
      8: 'ocho',
      9: 'nueve',
      10: 'diez',
      11: 'once',
      12: 'doce',
      13: 'trece',
      14: 'catorce',
      15: 'quince',
      16: 'dieciseis',
      17: 'diecisiete',
      18: 'dieciocho',
      19: 'diecinueve',
      20: 'veinte',
      21: 'veintiuno',
      22: 'veintidos',
      23: 'veintitres',
      24: 'veinticuatro',
      25: 'veinticinco',
      26: 'veintiseis',
      27: 'veintisiete',
      28: 'veintiocho',
      29: 'veintinueve',
    };
    return mapa[n] ?? '';
  }

  static String _decenas(int n) {
    if (n <= 29) return _unidades(n);
    final d = n ~/ 10;
    final r = n % 10;

    const decenas = {
      3: 'treinta',
      4: 'cuarenta',
      5: 'cincuenta',
      6: 'sesenta',
      7: 'setenta',
      8: 'ochenta',
      9: 'noventa',
    };

    final base = decenas[d] ?? '';
    if (r == 0) return base;
    return '$base y ${_unidades(r)}';
  }

  static String _centenas(int n) {
    if (n < 100) return _decenas(n);
    if (n == 100) return 'cien';

    final c = n ~/ 100;
    final r = n % 100;

    const centenas = {
      1: 'ciento',
      2: 'doscientos',
      3: 'trescientos',
      4: 'cuatrocientos',
      5: 'quinientos',
      6: 'seiscientos',
      7: 'setecientos',
      8: 'ochocientos',
      9: 'novecientos',
    };

    final base = centenas[c] ?? '';
    if (r == 0) return base;
    return '$base ${_numeroALetras(r)}';
  }

  static String _miles(int n) {
    final m = n ~/ 1000;
    final r = n % 1000;
    final miles = m == 1 ? 'mil' : '${_numeroALetras(m)} mil';
    if (r == 0) return miles;
    return '$miles ${_numeroALetras(r)}';
  }

  static String _millones(int n) {
    final m = n ~/ 1000000;
    final r = n % 1000000;
    final millones = m == 1 ? 'un millon' : '${_numeroALetras(m)} millones';
    if (r == 0) return millones;
    return '$millones ${_numeroALetras(r)}';
  }
}
