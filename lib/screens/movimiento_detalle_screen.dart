import 'package:flutter/material.dart';

import '../models/movimiento.dart';
import '../services/estado_diario_service.dart';

/// Shows the full details of a movimiento and lets the user create a
/// follow-up "agendamiento". On success the movimiento is marked as
/// revisado and the screen pops with `true` so the caller can refresh its
/// list.
class MovimientoDetalleScreen extends StatefulWidget {
  const MovimientoDetalleScreen({super.key, required this.movimiento});

  final Movimiento movimiento;

  @override
  State<MovimientoDetalleScreen> createState() =>
      _MovimientoDetalleScreenState();
}

class _MovimientoDetalleScreenState extends State<MovimientoDetalleScreen> {
  bool _isSaving = false;

  Future<void> _crearAgendamiento() async {
    final input = await showDialog<_AgendamientoInput>(
      context: context,
      builder: (_) => const _AgendamientoDialog(),
    );
    if (input == null) return;

    setState(() => _isSaving = true);
    try {
      await EstadoDiarioService.instance.crearAgendamiento(
        movimientoId: widget.movimiento.id,
        fechaHora: input.fechaHora,
        detalle: input.detalle,
      );
      await EstadoDiarioService.instance.marcarRevisado(widget.movimiento.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on EstadoDiarioException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movimiento;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del movimiento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              m.caratulado ?? m.rol ?? 'Movimiento sin título',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DetalleRow(label: 'Rol', value: m.rol),
            _DetalleRow(label: 'Rol único', value: m.rolUnico),
            _DetalleRow(label: 'Jurisdicción', value: m.jurisdiccion),
            _DetalleRow(label: 'Tribunal', value: m.tribunal),
            _DetalleRow(label: 'Estado', value: m.estado),
            _DetalleRow(label: 'Tipo de causa', value: m.tipoCausa),
            _DetalleRow(label: 'RUT', value: m.rut),
            _DetalleRow(label: 'Fecha de ingreso', value: _formatDate(m.fechaIngreso)),
            _DetalleRow(
              label: 'Fecha estado diario',
              value: _formatDate(m.fechaEstadoDiario),
            ),
            _DetalleRow(label: 'Nivel pendiente', value: m.nivelPendiente),
            _DetalleRow(
              label: 'Fecha pendiente',
              value: _formatDate(m.fechaPendiente),
            ),
            _DetalleRow(label: 'Usuario pendiente', value: m.usuarioPendiente),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _crearAgendamiento,
              icon: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: const Text('Crear agendamiento'),
            ),
          ],
        ),
      ),
    );
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _DetalleRow extends StatelessWidget {
  const _DetalleRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AgendamientoInput {
  _AgendamientoInput({required this.fechaHora, required this.detalle});

  final DateTime fechaHora;
  final String detalle;
}

class _AgendamientoDialog extends StatefulWidget {
  const _AgendamientoDialog();

  @override
  State<_AgendamientoDialog> createState() => _AgendamientoDialogState();
}

class _AgendamientoDialogState extends State<_AgendamientoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detalleController = TextEditingController();

  DateTime? _fecha;
  TimeOfDay? _hora;
  bool _showFechaHoraError = false;

  @override
  void dispose() {
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    final fecha = _fecha;
    final hora = _hora;
    if (fecha == null || hora == null) {
      setState(() => _showFechaHoraError = true);
      return;
    }
    if (!formOk) return;

    Navigator.of(context).pop(
      _AgendamientoInput(
        fechaHora: DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          hora.hour,
          hora.minute,
        ),
        detalle: _detalleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fecha = _fecha;
    final hora = _hora;
    final dateLabel = fecha == null
        ? 'Elegir fecha'
        : '${fecha.day.toString().padLeft(2, '0')}/'
              '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    final timeLabel = hora == null ? 'Elegir hora' : hora.format(context);

    return AlertDialog(
      title: const Text('Crear agendamiento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFecha,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(dateLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickHora,
                    icon: const Icon(Icons.access_time_outlined),
                    label: Text(timeLabel),
                  ),
                ),
              ],
            ),
            if (_showFechaHoraError && (fecha == null || hora == null)) ...[
              const SizedBox(height: 8),
              Text(
                'Selecciona fecha y hora.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _detalleController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Detalle',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Ingresa un detalle'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
