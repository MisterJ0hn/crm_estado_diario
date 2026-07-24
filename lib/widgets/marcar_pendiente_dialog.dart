import 'package:flutter/material.dart';

/// Result of [MarcarPendienteDialog]: the urgency level, the follow-up
/// message and the date/time it's due.
class PendienteInput {
  PendienteInput({
    required this.nivel,
    required this.mensaje,
    required this.fechaHora,
  });

  final String nivel;
  final String mensaje;
  final DateTime fechaHora;
}

/// Dialog to collect the data needed to mark a movimiento as pendiente:
/// urgency level (bajo/medio/alto), a follow-up message and a due
/// date/time.
class MarcarPendienteDialog extends StatefulWidget {
  const MarcarPendienteDialog({super.key});

  @override
  State<MarcarPendienteDialog> createState() => _MarcarPendienteDialogState();
}

class _MarcarPendienteDialogState extends State<MarcarPendienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mensajeController = TextEditingController();

  String _nivel = 'medio';
  DateTime? _fecha;
  TimeOfDay? _hora;
  bool _showFechaHoraError = false;

  @override
  void dispose() {
    _mensajeController.dispose();
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
      PendienteInput(
        nivel: _nivel,
        mensaje: _mensajeController.text.trim(),
        fechaHora: DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          hora.hour,
          hora.minute,
        ),
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
      title: const Text('Marcar como pendiente'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nivel', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bajo', label: Text('Bajo')),
                ButtonSegment(value: 'medio', label: Text('Medio')),
                ButtonSegment(value: 'alto', label: Text('Alto')),
              ],
              selected: {_nivel},
              onSelectionChanged: (selection) =>
                  setState(() => _nivel = selection.first),
            ),
            const SizedBox(height: 16),
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
              controller: _mensajeController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Ingresa un mensaje'
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
