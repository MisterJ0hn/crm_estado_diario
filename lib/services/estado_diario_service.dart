import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/jurisdiccion.dart';
import '../models/movimiento.dart';
import 'auth_service.dart';

/// Error thrown for any estado-diario request failure, with a message safe
/// to show to the user.
class EstadoDiarioException implements Exception {
  EstadoDiarioException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One page of movements, plus the total count across all pages.
class MovimientosPage {
  MovimientosPage({required this.items, required this.total});

  final List<Movimiento> items;
  final int total;
}

/// Fetches and mutates "estado diario" data on the CRM API.
class EstadoDiarioService {
  EstadoDiarioService._();

  static final EstadoDiarioService instance = EstadoDiarioService._();

  Future<MovimientosPage> getNoLeidos({
    required int page,
    required int limit,
    int? jurisdiccionId,
    DateTime? fecha,
    String? rut,
  }) => _getLista(
    'no-leidos',
    page: page,
    limit: limit,
    jurisdiccionId: jurisdiccionId,
    fecha: fecha,
    rut: rut,
  );

  Future<MovimientosPage> getRevisados({
    required int page,
    required int limit,
    int? jurisdiccionId,
    DateTime? fecha,
    String? rut,
  }) => _getLista(
    'leidos',
    page: page,
    limit: limit,
    jurisdiccionId: jurisdiccionId,
    fecha: fecha,
    rut: rut,
  );

  Future<MovimientosPage> getPendientes({
    required int page,
    required int limit,
    int? jurisdiccionId,
    DateTime? fecha,
    String? rut,
  }) => _getLista(
    'pendientes',
    page: page,
    limit: limit,
    jurisdiccionId: jurisdiccionId,
    fecha: fecha,
    rut: rut,
  );

  /// Fetches the list of jurisdicciones available for filtering, from
  /// GET {baseUrl}/estado-diario/jurisdicciones.
  Future<List<Jurisdiccion>> getJurisdicciones() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await AuthService.instance.getToken();
    if (token == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/jurisdicciones');

    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EstadoDiarioException('Error del servidor (${response.statusCode}).');
    }

    final data = _tryDecode(response.body);
    final raw = data?['jurisdicciones'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => Jurisdiccion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Calls GET {baseUrl}/estado-diario/{path}?limit=&page=&jurisdiccion=&fecha=&rut=
  /// with the stored auth token attached.
  Future<MovimientosPage> _getLista(
    String path, {
    required int page,
    required int limit,
    int? jurisdiccionId,
    DateTime? fecha,
    String? rut,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await AuthService.instance.getToken();
    if (token == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/$path').replace(
      queryParameters: {
        'limit': '$limit',
        'page': '$page',
        if (jurisdiccionId != null) 'jurisdiccion': '$jurisdiccionId',
        if (fecha != null) 'fecha': _formatFecha(fecha),
        if (rut != null && rut.isNotEmpty) 'rut': rut,
      },
    );

    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EstadoDiarioException('Error del servidor (${response.statusCode}).');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw EstadoDiarioException('Respuesta inválida del servidor.');
    }

    final movimientosRaw = data['movimientos'] as List<dynamic>? ?? const [];
    final items = movimientosRaw
        .map((e) => Movimiento.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = data['total'] as int? ?? items.length;

    return MovimientosPage(items: items, total: total);
  }

  /// Calls POST {baseUrl}/estado-diario/{id}/agenda to create a follow-up
  /// agendamiento for the given movimiento. Returns the new agenda id.
  Future<int> crearAgendamiento({
    required int movimientoId,
    required DateTime fechaHora,
    required String detalle,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await AuthService.instance.getToken();
    final username = await AuthService.instance.getUsername();
    if (token == null || username == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/$movimientoId/agenda');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'fecha_hora': _formatFechaHora(fechaHora),
              'detalle': detalle,
              'username': username,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }

    final data = _tryDecode(response.body);
    final exito = data?['exito'] as bool? ?? false;
    if (!exito) {
      throw EstadoDiarioException(
        data?['mensaje'] as String? ?? 'No se pudo crear el agendamiento.',
      );
    }

    return data!['id'] as int;
  }

  /// Calls POST {baseUrl}/estado-diario/fcm/token to register this device's
  /// FCM token for push notifications.
  Future<void> registrarTokenFcm({
    required String username,
    required String token,
    required String plataforma,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final authToken = await AuthService.instance.getToken();
    if (authToken == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/fcm/token');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'username': username,
              'token': token,
              'plataforma': plataforma,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }

    final data = _tryDecode(response.body);
    final exito =
        data?['exito'] as bool? ??
        (response.statusCode >= 200 && response.statusCode < 300);
    if (!exito) {
      throw EstadoDiarioException(
        data?['mensaje'] as String? ?? 'No se pudo registrar el token FCM.',
      );
    }
  }

  /// Calls POST {baseUrl}/estado-diario/{id}/leido to mark a movimiento as
  /// revisado.
  Future<void> marcarRevisado(int movimientoId) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await AuthService.instance.getToken();
    if (token == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/$movimientoId/leido');

    http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }

    final data = _tryDecode(response.body);
    final exito =
        data?['exito'] as bool? ??
        (response.statusCode >= 200 && response.statusCode < 300);
    if (!exito) {
      throw EstadoDiarioException(
        data?['mensaje'] as String? ?? 'No se pudo marcar como revisado.',
      );
    }
  }

  /// Calls POST {baseUrl}/estado-diario/{id}/pendiente to flag a movimiento
  /// as pending follow-up, with an urgency level, a message and a due date.
  Future<void> marcarPendiente({
    required int movimientoId,
    required String nivel,
    required String mensaje,
    required DateTime fechaHora,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await AuthService.instance.getToken();
    final username = await AuthService.instance.getUsername();
    if (token == null || username == null) {
      throw EstadoDiarioException('Sesión no válida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('$baseUrl/estado-diario/$movimientoId/pendiente');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'nivel': nivel,
              'mensaje': mensaje,
              'fecha_hora': _formatFechaHora(fechaHora),
              'username': username,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EstadoDiarioException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw EstadoDiarioException('Sesión expirada. Vuelve a iniciar sesión.');
    }

    final data = _tryDecode(response.body);
    final exito = data?['exito'] as bool? ?? false;
    if (!exito) {
      throw EstadoDiarioException(
        data?['mensaje'] as String? ?? 'No se pudo marcar como pendiente.',
      );
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String _formatFecha(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static String _formatFechaHora(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
  }
}
