import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'orders_page.dart';
import 'inventory_page.dart';
import 'history_page.dart';
import 'people_page.dart';
import 'new_order_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Resumen', 'Órdenes', 'Inventario', 'Historial', 'Personas'];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TU SOLUTION', style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 2, fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          )),
          Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: IndexedStack(index: _index, children: [
        DashboardPage(onShowOrders: () => setState(() => _index = 1),
            onShowInventory: () => setState(() => _index = 2)),
        const OrdersPage(),
        const InventoryPage(),
        const HistoryPage(),
        const PeoplePage(),
      ]),
      floatingActionButton: _index == 0 || _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const NewOrderPage())),
              icon: const Icon(Icons.add), label: const Text('Nueva orden'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment), label: 'Órdenes'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups), label: 'Personas'),
        ],
      ),
    );
  }
}
