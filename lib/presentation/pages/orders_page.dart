import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../widgets/common.dart';
import 'order_detail_page.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  RepairStatus? _status;
  String _text = '';

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          TextField(
            onChanged: (value) => setState(() => _text = value.toLowerCase()),
            decoration: fieldDecoration('Buscar orden, cliente, equipo o serie')
                .copyWith(prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: const Text('Todas'), selected: _status == null,
              onSelected: (_) => setState(() => _status = null))),
            for (final value in RepairStatus.values)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(value.label), selected: _status == value,
                onSelected: (_) => setState(() => _status = value))),
          ])),
        ]),
      ),
      Expanded(child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyMessage('Error al consultar órdenes: $e'),
        data: (items) {
          final filtered = items.where((item) {
            if (_status != null && item.status != _status) return false;
            final full = '${item.order.id} ${item.customer.name} '
                '${item.customer.phone} ${item.deviceTitle} '
                '${item.device.serialNumber} ${item.order.reportedIssue} '
                '${item.technician?.name ?? ''}'.toLowerCase();
            return full.contains(_text);
          }).toList();
          if (filtered.isEmpty) return const EmptyMessage('No hay órdenes con esos filtros.');
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            children: [for (final item in filtered)
              OrderTile(item: item, onTap: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: item.order.id)))),
            ]);
        },
      )),
    ]);
  }
}
