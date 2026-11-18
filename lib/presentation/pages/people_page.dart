import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/workshop_database.dart';
import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../viewmodels/commands.dart';
import '../widgets/common.dart';
import '../widgets/edit_dialogs.dart';
import 'order_detail_page.dart';

class PeoplePage extends StatelessWidget {
  const PeoplePage({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 2,
    child: Column(children: [
      TabBar(tabs: [Tab(text: 'Clientes'), Tab(text: 'Técnicos')]),
      Expanded(child: TabBarView(children: [
        _CustomerList(),
        _TechnicianList(),
      ])),
    ]),
  );
}

class _CustomerList extends ConsumerStatefulWidget {
  const _CustomerList();
  @override
  ConsumerState<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends ConsumerState<_CustomerList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final devices = ref.watch(devicesProvider).valueOrNull ?? <Device>[];
    final orders = ref.watch(ordersProvider).valueOrNull ?? <OrderOverview>[];
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(
        decoration: fieldDecoration('Buscar cliente o teléfono')
            .copyWith(prefixIcon: const Icon(Icons.search)),
        onChanged: (value) => setState(() => _filter = value.toLowerCase()),
      )),
      Expanded(child: customers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyMessage('No se pudieron cargar clientes: $e'),
        data: (items) {
          final result = items.where((c) =>
              '${c.name} ${c.phone}'.toLowerCase().contains(_filter)).toList();
          if (result.isEmpty) return const EmptyMessage(
              'No hay clientes. Los clientes se registran al crear una orden.');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            children: [for (final customer in result) Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(customer.name),
                subtitle: Text(customer.phone),
                children: [
                  for (final device in devices.where((d) => d.customerId == customer.id))
                    _DeviceHistoryTile(device: device, orders: orders),
                ],
              ),
            )]);
        },
      )),
    ]);
  }
}

class _DeviceHistoryTile extends StatelessWidget {
  const _DeviceHistoryTile({required this.device, required this.orders});
  final Device device;
  final List<OrderOverview> orders;

  @override
  Widget build(BuildContext context) {
    final visits = orders.where((o) => o.device.id == device.id).toList();
    return ExpansionTile(
      leading: const Icon(Icons.devices_outlined),
      title: Text('${device.brand} ${device.model}'),
      subtitle: Text('${device.type} · Serie: ${device.serialNumber}'),
      trailing: Text('${visits.length} visitas'),
      children: [for (final visit in visits) ListTile(
        contentPadding: const EdgeInsets.only(left: 60, right: 16),
        title: Text('Orden #${visit.order.id} · ${visit.status.label}'),
        subtitle: Text(visit.order.reportedIssue,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => OrderDetailPage(orderId: visit.order.id))),
      )],
    );
  }
}

class _TechnicianList extends ConsumerWidget {
  const _TechnicianList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technicians = ref.watch(techniciansProvider);
    final orders = ref.watch(ordersProvider).valueOrNull ?? <OrderOverview>[];
    return technicians.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyMessage('No se pudieron cargar técnicos: $e'),
      data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          const Text('Los tres técnicos del taller. Tocá el lápiz para poner sus nombres reales.'),
          const SizedBox(height: 16),
          for (final t in items) Card(child: Column(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.engineering_outlined)),
              title: Text(t.name),
              subtitle: Text('${orders.where((o) => o.order.technicianId == t.id &&
                  o.status.isOpen).length} órdenes abiertas asignadas'),
              trailing: IconButton(
                tooltip: 'Editar nombre', icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(context, ref, t)),
            ),
            for (final assigned in orders.where((o) =>
                o.order.technicianId == t.id && o.status.isOpen))
              ListTile(
                dense: true, contentPadding: const EdgeInsets.only(left: 65, right: 16),
                title: Text('Orden #${assigned.order.id} · ${assigned.deviceTitle}'),
                subtitle: Text(assigned.status.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) =>
                    OrderDetailPage(orderId: assigned.order.id))),
              ),
          ])),
        ]),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Technician tech) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => TechnicianNameDialog(initialName: tech.name),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(technicianCommandsProvider.notifier).renameTechnician(tech.id, result);
      if (context.mounted) notifyResult(context, null);
    } catch (e) {
      if (context.mounted) notifyResult(context, e);
    }
  }
}
