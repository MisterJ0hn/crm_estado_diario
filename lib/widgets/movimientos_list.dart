import 'package:flutter/material.dart';

import '../models/jurisdiccion.dart';
import '../models/movimiento.dart';
import '../screens/movimiento_detalle_screen.dart';
import '../services/estado_diario_service.dart';
import 'marcar_pendiente_dialog.dart';

typedef FetchMovimientosPage =
    Future<MovimientosPage> Function({
      required int page,
      required int limit,
      int? jurisdiccionId,
      DateTime? fecha,
      String? rut,
    });

enum _Accion { revisado, pendiente }

/// Shared filter state for a [MovimientosList]. Immutable and comparable by
/// value so a controlling parent can hold a single instance and pass it to
/// several lists at once.
class MovimientosFiltro {
  const MovimientosFiltro({
    this.jurisdiccionId,
    this.jurisdiccionNombre,
    this.fecha,
    this.rut,
  });

  /// Defaults to the day before today, per the app's default view.
  factory MovimientosFiltro.diaAnterior() =>
      MovimientosFiltro(fecha: _fechaAyer());

  final int? jurisdiccionId;
  final String? jurisdiccionNombre;
  final DateTime? fecha;
  final String? rut;

  @override
  bool operator ==(Object other) =>
      other is MovimientosFiltro &&
      other.jurisdiccionId == jurisdiccionId &&
      other.fecha == fecha &&
      other.rut == rut;

  @override
  int get hashCode => Object.hash(jurisdiccionId, fecha, rut);
}

/// Scrollable list of movimientos, with pull-to-refresh and infinite scroll
/// pagination. When [mostrarAcciones] is true, each item shows a menu to
/// mark it as revisado or pendiente. [filtros] is controlled by the parent
/// so several lists can share the same filter selection; selecting new
/// filters calls [onFiltrosChanged] instead of mutating local state.
class MovimientosList extends StatefulWidget {
  const MovimientosList({
    super.key,
    required this.fetchPage,
    required this.filtros,
    required this.onFiltrosChanged,
    required this.refreshToken,
    required this.onCambio,
    this.mostrarAcciones = false,
    this.emptyMessage = 'No hay movimientos.',
  });

  final FetchMovimientosPage fetchPage;
  final MovimientosFiltro filtros;
  final ValueChanged<MovimientosFiltro> onFiltrosChanged;

  /// Bumped by the parent whenever a movimiento changes state in any of the
  /// sibling lists, so this list knows to reload too.
  final int refreshToken;

  /// Called after this list successfully changes a movimiento's state, so
  /// the parent can bump [refreshToken] for every list, including this one.
  final VoidCallback onCambio;

  final bool mostrarAcciones;
  final String emptyMessage;

  @override
  State<MovimientosList> createState() => _MovimientosListState();
}

class _MovimientosListState extends State<MovimientosList> {
  static const _limit = 20;

  final _scrollController = ScrollController();
  final _items = <Movimiento>[];

  int _page = 1;
  int _total = 0;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant MovimientosList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filtros != widget.filtros ||
        oldWidget.refreshToken != widget.refreshToken) {
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || _isLoadingFirstPage) return;
    if (_items.length >= _total) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.fetchPage(
        page: 1,
        limit: _limit,
        jurisdiccionId: widget.filtros.jurisdiccionId,
        fecha: widget.filtros.fecha,
        rut: widget.filtros.rut,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _total = result.total;
        _page = 1;
      });
    } on EstadoDiarioException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Ocurrió un error inesperado.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingFirstPage = false);
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    try {
      final result = await widget.fetchPage(
        page: nextPage,
        limit: _limit,
        jurisdiccionId: widget.filtros.jurisdiccionId,
        fecha: widget.filtros.fecha,
        rut: widget.filtros.rut,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _page = nextPage;
      });
    } on EstadoDiarioException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFiltros() async {
    final result = await showDialog<MovimientosFiltro>(
      context: context,
      builder: (_) => _FiltrosDialog(filtrosIniciales: widget.filtros),
    );
    if (result == null) return;
    widget.onFiltrosChanged(result);
  }

  void _quitarFiltro({
    bool jurisdiccion = false,
    bool fecha = false,
    bool rut = false,
  }) {
    widget.onFiltrosChanged(
      MovimientosFiltro(
        jurisdiccionId: jurisdiccion ? null : widget.filtros.jurisdiccionId,
        jurisdiccionNombre: jurisdiccion
            ? null
            : widget.filtros.jurisdiccionNombre,
        fecha: fecha ? null : widget.filtros.fecha,
        rut: rut ? null : widget.filtros.rut,
      ),
    );
  }

  Future<void> _openDetalle(Movimiento movimiento) async {
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MovimientoDetalleScreen(movimiento: movimiento),
      ),
    );
    if (actualizado == true) widget.onCambio();
  }

  Future<void> _onAccion(_Accion accion, Movimiento movimiento) async {
    switch (accion) {
      case _Accion.revisado:
        await _marcarRevisado(movimiento);
      case _Accion.pendiente:
        await _marcarPendiente(movimiento);
    }
  }

  Future<void> _marcarRevisado(Movimiento movimiento) async {
    final titulo = movimiento.caratulado ?? movimiento.rol ?? 'este movimiento';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como revisado'),
        content: Text('¿Confirmas marcar "$titulo" como revisado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await EstadoDiarioService.instance.marcarRevisado(movimiento.id);
      _showMessage('Movimiento marcado como revisado.');
      widget.onCambio();
    } on EstadoDiarioException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Ocurrió un error inesperado.');
    }
  }

  Future<void> _marcarPendiente(Movimiento movimiento) async {
    final input = await showDialog<PendienteInput>(
      context: context,
      builder: (_) => const MarcarPendienteDialog(),
    );
    if (input == null) return;

    try {
      await EstadoDiarioService.instance.marcarPendiente(
        movimientoId: movimiento.id,
        nivel: input.nivel,
        mensaje: input.mensaje,
        fechaHora: input.fechaHora,
      );
      _showMessage('Movimiento marcado como pendiente.');
      widget.onCambio();
    } on EstadoDiarioException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Ocurrió un error inesperado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFiltroBar(context),
        Expanded(child: _buildContenido(context)),
      ],
    );
  }

  Widget _buildFiltroBar(BuildContext context) {
    final filtros = widget.filtros;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _openFiltros,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtros'),
          ),
          if (filtros.jurisdiccionId != null)
            InputChip(
              label: Text('Jurisdicción: ${filtros.jurisdiccionNombre}'),
              onDeleted: () => _quitarFiltro(jurisdiccion: true),
            ),
          if (filtros.fecha != null)
            InputChip(
              label: Text('Fecha: ${_formatDate(filtros.fecha!)}'),
              onDeleted: () => _quitarFiltro(fecha: true),
            ),
          if (filtros.rut != null)
            InputChip(
              label: Text('RUT: ${filtros.rut}'),
              onDeleted: () => _quitarFiltro(rut: true),
            ),
        ],
      ),
    );
  }

  Widget _buildContenido(BuildContext context) {
    if (_isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadFirstPage,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(child: Text(widget.emptyMessage));
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final movimiento = _items[index];
          return _MovimientoCard(
            movimiento: movimiento,
            mostrarAcciones: widget.mostrarAcciones,
            onTap: () => _openDetalle(movimiento),
            onAccion: (accion) => _onAccion(accion, movimiento),
          );
        },
      ),
    );
  }
}

class _MovimientoCard extends StatelessWidget {
  const _MovimientoCard({
    required this.movimiento,
    required this.mostrarAcciones,
    required this.onTap,
    required this.onAccion,
  });

  final Movimiento movimiento;
  final bool mostrarAcciones;
  final VoidCallback onTap;
  final ValueChanged<_Accion> onAccion;

  @override
  Widget build(BuildContext context) {
    final fecha = movimiento.fechaEstadoDiario;
    final fechaLabel = fecha == null ? '' : _formatDate(fecha);

    final subtitleParts = [
      movimiento.rol,
      movimiento.jurisdiccion,
    ].whereType<String>().where((s) => s.isNotEmpty);

    return Card(
      color: _colorNivelPendiente(context, movimiento.nivelPendiente),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.markunread_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          movimiento.caratulado ?? movimiento.rol ?? 'Movimiento sin título',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (movimiento.nivelPendiente != null)
              Text(
                'Pendiente (${movimiento.nivelPendiente}) · '
                '${_formatDate(movimiento.fechaPendiente!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fechaLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(fechaLabel),
              ),
            if (mostrarAcciones)
              PopupMenuButton<_Accion>(
                onSelected: onAccion,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _Accion.revisado,
                    child: Text('Marcar como revisado'),
                  ),
                  PopupMenuItem(
                    value: _Accion.pendiente,
                    child: Text('Marcar como pendiente'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Color? _colorNivelPendiente(BuildContext context, String? nivel) {
  if (nivel == null) return null;
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (nivel.toLowerCase()) {
    case 'bajo':
      return dark ? Colors.green.shade900 : Colors.green.shade100;
    case 'medio':
      return dark ? Colors.yellow.shade900 : Colors.yellow.shade100;
    case 'alto':
      return dark ? Colors.red.shade900 : Colors.red.shade100;
    default:
      return null;
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

DateTime _fechaAyer() {
  final hoy = DateTime.now();
  return DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1));
}

class _FiltrosDialog extends StatefulWidget {
  const _FiltrosDialog({required this.filtrosIniciales});

  final MovimientosFiltro filtrosIniciales;

  @override
  State<_FiltrosDialog> createState() => _FiltrosDialogState();
}

class _FiltrosDialogState extends State<_FiltrosDialog> {
  late final _rutController = TextEditingController(
    text: widget.filtrosIniciales.rut,
  );
  late int? _jurisdiccionId = widget.filtrosIniciales.jurisdiccionId;
  late DateTime? _fecha = widget.filtrosIniciales.fecha;

  List<Jurisdiccion>? _jurisdicciones;
  String? _jurisdiccionesError;
  bool _isLoadingJurisdicciones = true;

  @override
  void initState() {
    super.initState();
    _cargarJurisdicciones();
  }

  @override
  void dispose() {
    _rutController.dispose();
    super.dispose();
  }

  Future<void> _cargarJurisdicciones() async {
    setState(() {
      _isLoadingJurisdicciones = true;
      _jurisdiccionesError = null;
    });
    try {
      final result = await EstadoDiarioService.instance.getJurisdicciones();
      if (!mounted) return;
      setState(() => _jurisdicciones = result);
    } on EstadoDiarioException catch (e) {
      if (mounted) setState(() => _jurisdiccionesError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _jurisdiccionesError =
              'No se pudieron cargar las jurisdicciones.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingJurisdicciones = false);
    }
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  String? _nombreDe(int? id) {
    if (id == null) return null;
    for (final j in _jurisdicciones ?? const <Jurisdiccion>[]) {
      if (j.id == id) return j.nombre;
    }
    return null;
  }

  void _aplicar() {
    Navigator.of(context).pop(
      MovimientosFiltro(
        jurisdiccionId: _jurisdiccionId,
        jurisdiccionNombre: _nombreDe(_jurisdiccionId),
        fecha: _fecha,
        rut: _rutController.text.trim().isEmpty
            ? null
            : _rutController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fecha = _fecha;
    final dateLabel = fecha == null ? 'Cualquier fecha' : _formatDate(fecha);

    return AlertDialog(
      title: const Text('Filtrar movimientos'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildJurisdiccionField(),
            const SizedBox(height: 16),
            TextField(
              controller: _rutController,
              decoration: const InputDecoration(
                labelText: 'RUT',
                border: OutlineInputBorder(),
              ),
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
                if (fecha != null)
                  IconButton(
                    onPressed: () => setState(() => _fecha = null),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Quitar fecha',
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const MovimientosFiltro()),
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aplicar, child: const Text('Aplicar')),
      ],
    );
  }

  Widget _buildJurisdiccionField() {
    if (_isLoadingJurisdicciones) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_jurisdiccionesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _jurisdiccionesError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _cargarJurisdicciones,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    final jurisdicciones = _jurisdicciones!;
    final validIds = jurisdicciones.map((j) => j.id).toSet();
    final valorInicial = validIds.contains(_jurisdiccionId)
        ? _jurisdiccionId
        : null;

    return DropdownButtonFormField<int?>(
      initialValue: valorInicial,
      decoration: const InputDecoration(
        labelText: 'Jurisdicción',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
        ...jurisdicciones.map(
          (j) => DropdownMenuItem<int?>(value: j.id, child: Text(j.nombre)),
        ),
      ],
      onChanged: (value) => setState(() => _jurisdiccionId = value),
    );
  }
}
