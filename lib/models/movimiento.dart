/// A single "estado diario" movement, as returned by the
/// estado-diario/no-leidos, estado-diario/leidos and estado-diario/pendientes
/// endpoints.
class Movimiento {
  Movimiento({
    required this.id,
    this.jurisdiccion,
    this.rol,
    this.rolUnico,
    this.fechaIngreso,
    this.caratulado,
    this.tribunal,
    this.estado,
    this.tipoCausa,
    this.rut,
    this.fechaEstadoDiario,
    this.nivelPendiente,
    this.fechaPendiente,
    this.usuarioPendiente,
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      id: json['id'] as int,
      jurisdiccion: json['jurisdiccion'] as String?,
      rol: json['rol'] as String?,
      rolUnico: json['rol_unico'] as String?,
      fechaIngreso: _parseDate(json['fecha_ingreso'] as String?),
      caratulado: json['caratulado'] as String?,
      tribunal: json['tribunal'] as String?,
      estado: json['estado'] as String?,
      tipoCausa: json['tipo_causa'] as String?,
      rut: json['rut'] as String?,
      fechaEstadoDiario: _parseDate(json['fecha_estado_diario'] as String?),
      nivelPendiente: json['nivel_pendiente'] as String?,
      fechaPendiente: _parseDate(json['fecha_pendiente'] as String?),
      usuarioPendiente: json['usuario_pendiente'] as String?,
    );
  }

  final int id;
  final String? jurisdiccion;
  final String? rol;
  final String? rolUnico;
  final DateTime? fechaIngreso;
  final String? caratulado;
  final String? tribunal;
  final String? estado;
  final String? tipoCausa;
  final String? rut;
  final DateTime? fechaEstadoDiario;

  /// Only present when the movimiento comes from estado-diario/pendientes.
  final String? nivelPendiente;
  final DateTime? fechaPendiente;
  final String? usuarioPendiente;

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
