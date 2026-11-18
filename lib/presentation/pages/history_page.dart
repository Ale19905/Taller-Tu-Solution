import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../widgets/common.dart';
import 'order_detail_page.dart';

/// Searchable history is grouped by physical device (serial number) so every
/// repeat visit stays visible, even when its older order is closed.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _query = '';
  bool _closedOnly = false;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          TextField(decoration: fieldDecoration('Buscar cliente, teléfono, modelo o serie')
              .copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (text) => setState(() => _query = text.toLowerCase())),
          Row(children: [
            FilterChip(label: const Text('Solo entregadas o canceladas'),
              selected: _closedOnly,
              onSelected: (value) => setState(() => _closedOnly = value)),
          ]),
        ])),
      Expanded(child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyMessage('No se pudo consultar el historial: $e'),
        data: (items) {
          final matching = items.where((o) {
            if (_closedOnly && o.status.isOpen) return false;
            final search = '${o.customer.name} ${o.customer.phone} '
                '${o.device.brand} ${o.device.model} ${o.device.serialNumber} '
                '${o.order.reportedIssue}'.toLowerCase();
            return search.contains(_query);
          }).toList();
          if (matching.isEmpty) return const EmptyMessage('No hay visitas para esta búsqueda.',
            icon: Icons.history);
          final groups = <int, List<OrderOverview>>{};
          for (final item in matching) {
            groups.putIfAbsent(item.device.id, () => []).add(item);
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), children: [
            for (final group in groups.values) ...[
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                const Icon(Icons.devices_other, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${group.first.device.brand} ${group.first.device.model}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${group.first.customer.name} · Serie: ${group.first.device.serialNumber}',
                    style: Theme.of(context).textTheme.bodySmall),
                ])),
                Text('${group.length} visita${group.length == 1 ? '' : 's'}'),
              ]))),
              const SizedBox(height: 6),
              for (final item in group)
                Padding(padding: const EdgeInsets.only(left: 10),
                  child: OrderTile(item: item, onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) =>
                      OrderDetailPage(orderId: item.order.id))))),
              const SizedBox(height: 10),
            ],
          ]);
        },
      )),
    ]);
  }
}
