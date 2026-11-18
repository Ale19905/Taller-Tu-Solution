import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../widgets/common.dart';
import 'order_detail_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.onShowOrders,
    required this.onShowInventory});
  final VoidCallback onShowOrders;
  final VoidCallback onShowInventory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final partsAsync = ref.watch(partsProvider);
    final techsAsync = ref.watch(techniciansProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyMessage('No se pudieron cargar los datos: $error'),
      data: (orders) {
        final open = orders.where((o) => o.status.isOpen).toList();
        final repairing = orders.where((o) => o.status == RepairStatus.repairing).length;
        final ready = orders.where((o) => o.status == RepairStatus.ready).length;
        final low = partsAsync.valueOrNull
            ?.where((p) => p.stock <= p.minimumStock).toList() ?? [];
        final technicians = techsAsync.valueOrNull ?? [];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
          Text('El taller de un vistazo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Información local, disponible sin internet',
              style: TextStyle(color: Colors.blueGrey.shade600)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _MetricCard('Abiertas', '${open.length}', Icons.assignment_outlined,
                onTap: onShowOrders)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard('En reparación', '$repairing', Icons.build_outlined,
                onTap: onShowOrders)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MetricCard('Listas', '$ready', Icons.check_circle_outline,
                onTap: onShowOrders)),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard('Stock bajo', '${low.length}',
                Icons.warning_amber_rounded, onTap: onShowInventory)),
          ]),
          const SectionHeader('Carga de trabajo por técnico'),
          if (technicians.isEmpty)
            const EmptyMessage('No hay técnicos registrados.')
          else
            Card(child: Column(children: [
              for (final technician in technicians)
                ListTile(
                  leading: CircleAvatar(child: Text(technician.name[0].toUpperCase())),
                  title: Text(technician.name),
                  subtitle: const Text('Órdenes abiertas asignadas'),
                  trailing: Text('${open.where((o) => o.order.technicianId == technician.id).length}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
                ),
            ])),
          SectionHeader('Órdenes recientes', trailing: TextButton(
            onPressed: onShowOrders, child: const Text('Ver todas'))),
          if (open.isEmpty)
            const EmptyMessage('No hay órdenes abiertas. Creá una con el botón +.')
          else
            for (final order in open.take(4))
              OrderTile(item: order, onTap: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: order.order.id)))),
          if (low.isNotEmpty) ...[
            SectionHeader('Repuestos a reponer', trailing: TextButton(
              onPressed: onShowInventory, child: const Text('Ver stock'))),
            for (final part in low.take(4))
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Color(0xFFB36C23)),
                title: Text(part.name),
                subtitle: Text(part.code),
                trailing: Text('${part.stock} / mín. ${part.minimumStock}'),
              ),
          ],
        ]);
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, {this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23),
        const SizedBox(height: 14),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
      ],
    )),
  ));
}
