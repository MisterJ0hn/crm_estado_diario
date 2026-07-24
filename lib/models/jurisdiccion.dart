/// A jurisdicción option, as returned by GET /api/estado-diario/jurisdicciones.
class Jurisdiccion {
  Jurisdiccion({required this.id, required this.nombre});

  factory Jurisdiccion.fromJson(Map<String, dynamic> json) {
    return Jurisdiccion(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  final int id;
  final String nombre;
}
