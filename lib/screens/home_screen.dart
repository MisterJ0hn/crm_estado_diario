import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/estado_diario_service.dart';
import '../widgets/movimientos_list.dart';
import 'login_screen.dart';

/// Post-login landing screen. Shows the three estado-diario buckets as
/// bottom navigation tabs, starting on "No leídos".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _titulos = ['No leídos', 'Pendientes', 'Revisados'];

  int _selectedIndex = 0;

  /// Shared across the three tabs, so picking a filter in one applies to
  /// all of them.
  MovimientosFiltro _filtros = MovimientosFiltro.diaAnterior();

  /// Bumped whenever a movimiento changes state in any tab, so all three
  /// lists reload and stay in sync with each other.
  int _refreshToken = 0;

  void _onCambio() => setState(() => _refreshToken++);

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      MovimientosList(
        fetchPage: EstadoDiarioService.instance.getNoLeidos,
        filtros: _filtros,
        onFiltrosChanged: (filtros) => setState(() => _filtros = filtros),
        refreshToken: _refreshToken,
        onCambio: _onCambio,
        mostrarAcciones: true,
        emptyMessage: 'No hay movimientos sin leer.',
      ),
      MovimientosList(
        fetchPage: EstadoDiarioService.instance.getPendientes,
        filtros: _filtros,
        onFiltrosChanged: (filtros) => setState(() => _filtros = filtros),
        refreshToken: _refreshToken,
        onCambio: _onCambio,
        mostrarAcciones: true,
        emptyMessage: 'No hay movimientos pendientes.',
      ),
      MovimientosList(
        fetchPage: EstadoDiarioService.instance.getRevisados,
        filtros: _filtros,
        onFiltrosChanged: (filtros) => setState(() => _filtros = filtros),
        refreshToken: _refreshToken,
        onCambio: _onCambio,
        emptyMessage: 'No hay movimientos revisados.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_selectedIndex]),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mark_email_unread_outlined),
            selectedIcon: Icon(Icons.mark_email_unread),
            label: 'No leídos',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions_outlined),
            selectedIcon: Icon(Icons.pending_actions),
            label: 'Pendientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.done_all_outlined),
            selectedIcon: Icon(Icons.done_all),
            label: 'Revisados',
          ),
        ],
      ),
    );
  }
}
