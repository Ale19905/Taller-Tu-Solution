import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/workshop_database.dart';
import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../viewmodels/commands.dart';
import '../widgets/common.dart';
import '../widgets/edit_dialogs.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final overviews = orders.valueOrNull;
    if (overviews == null) {
      return Scaffold(appBar: AppBar(title: Text('Orden #$orderId')),
        body: Center(child: orders.isLoading
            ? const CircularProgressIndicator()
            : const Text('No se pudieron cargar los datos.')));
    }
    final matching = overviews.where((o) => o.order.id == orderId);
    if (matching.isEmpty) return Scaffold(
      appBar: AppBar(title: Text('Orden #$orderId')),
      body: const EmptyMessage('No se encontró la orden.'));
    final order = matching.first;
    final labor = ref.watch(laborProvider(orderId)).valueOrNull ?? <LaborEntry>[];
    final used = ref.watch(usedPartsProvider(orderId)).valueOrNull ?? <UsedPartOverview>[];
    final laborCost = labor.fold<int>(0, (sum, e) => sum + e.costCents);
    final partsCost = used.fold<int>(0, (sum, e) => sum + e.totalCents);
    final canEdit = order.status == RepairStatus.repairing;

    return Scaffold(
      appBar: AppBar(title: Text('Orden #$orderId')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(order.deviceTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold))),
              StatusChip(order.status),
            ]),
            const SizedBox(height: 5),
            Text('${order.device.type} · Serie: ${order.device.serialNumber}'),
            const Divider(height: 28),
            IconText(Icons.person_outline,
                '${order.customer.name} · ${order.customer.phone}'),
            const SizedBox(height: 7),
            IconText(Icons.engineering_outlined,
                'Responsable: ${order.technician?.name ?? 'Sin asignar'}'),
            const SizedBox(height: 7),
            IconText(Icons.calendar_today_outlined, dateLabel(order.order.createdAt)),
            const SectionHeader('Falla reportada'),
            Text(order.order.reportedIssue),
          ]))),
        const SectionHeader('Acciones'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (order.status == RepairStatus.received)
            FilledButton.icon(
              onPressed: () => _selectTechnician(context, ref, order),
              icon: const Icon(Icons.handyman_outlined),
              label: const Text('Tomar orden')),
          if (canEdit) ...[
            OutlinedButton.icon(onPressed: () => _selectTechnician(context, ref, order,
                reassign: true), icon: const Icon(Icons.swap_horiz),
                label: const Text('Reasignar')),
            FilledButton.icon(onPressed: () => _setStatus(context, ref, RepairStatus.ready),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Marcar lista')),
          ],
          if (order.status == RepairStatus.ready)
            FilledButton.icon(onPressed: () => _setStatus(context, ref,
                RepairStatus.delivered), icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Marcar entregada')),
          if (order.status.isOpen)
            TextButton.icon(onPressed: () => _setStatus(context, ref,
                RepairStatus.cancelled), icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar orden')),
          if (!order.status.isOpen)
            const Text('Orden cerrada · Información de solo lectura'),
        ]),
        SectionHeader('Diagnóstico',
          trailing: order.status.isOpen
            ? IconButton(icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editDiagnosis(context, ref, order.order.diagnosis))
            : null),
        Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Text(order.order.diagnosis.isEmpty
            ? 'Todavía no se registró un diagnóstico.' : order.order.diagnosis))),
        SectionHeader('Mano de obra',
          trailing: canEdit ? TextButton.icon(
            onPressed: () => _addLabor(context, ref),
            icon: const Icon(Icons.add), label: const Text('Agregar')) : null),
        if (labor.isEmpty)
          const Card(child: ListTile(title: Text('Sin trabajos registrados')))
        else
          Card(child: Column(children: [
            for (final item in labor)
              ListTile(
                title: Text(item.description),
                subtitle: const Text('Trabajo realizado'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(item.costCents)),
                  if (canEdit) IconButton(
                    tooltip: 'Eliminar mano de obra',
                    onPressed: () => _deleteLabor(context, ref, item.id),
                    icon: const Icon(Icons.delete_outline)),
                ]),
              ),
          ])),
        SectionHeader('Repuestos utilizados',
          trailing: canEdit ? TextButton.icon(
            onPressed: () => _addUsedPart(context, ref),
            icon: const Icon(Icons.add), label: const Text('Agregar')) : null),
        if (used.isEmpty)
          const Card(child: ListTile(title: Text('Sin repuestos utilizados')))
        else
          Card(child: Column(children: [
            for (final item in used)
              ListTile(
                title: Text(item.usage.partName),
                subtitle: Text('${item.usage.quantity} × ${money(item.usage.unitPriceCents)} '
                    '· ${item.usage.partCode}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(item.totalCents)),
                  if (canEdit) IconButton(
                    tooltip: 'Quitar y devolver stock',
                    onPressed: () => _deleteUsage(context, ref, item.usage.id),
                    icon: const Icon(Icons.delete_outline)),
                ]),
              ),
          ])),
        const SectionHeader('Total de la reparación'),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          _CostLine('Mano de obra', laborCost),
          const SizedBox(height: 8),
          _CostLine('Repuestos', partsCost),
          const Divider(height: 24),
          Row(children: [
            const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
            Text(money(laborCost + partsCost), style: Theme.of(context)
                .textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ]))),
        const SizedBox(height: 10),
        Text('Los costos de los repuestos quedan guardados al usarlos, '
          'aunque luego cambie su precio en inventario.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
      ]),
    );
  }

  Future<void> _perform(BuildContext context, Future<void> Function() task,
      {String success = 'Cambios guardados'}) async {
    try {
      await task();
      if (context.mounted) notifyResult(context, null, success: success);
    } catch (e) {
      if (context.mounted) notifyResult(context, e);
    }
  }

  Future<void> _selectTechnician(BuildContext context, WidgetRef ref,
      OrderOverview order, {bool reassign = false}) async {
    final technicians = ref.read(techniciansProvider).valueOrNull ?? <Technician>[];
    final chosen = await showDialog<int>(context: context, builder: (ctx) =>
      SimpleDialog(title: Text(reassign ? 'Reasignar orden' : '¿Quién toma la orden?'),
        children: [
          for (final t in technicians)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.name)),
            ),
        ],
      ));
    if (chosen == null || !context.mounted) return;
    if (reassign && !(await confirmAction(context, 'Confirmar reasignación',
        'La orden dejará de estar asignada a ${order.technician?.name ?? 'su técnico actual'}.'))) {
      return;
    }
    if (!context.mounted) return;
    await _perform(context,
        () => ref.read(orderCommandsProvider.notifier).assignOrder(orderId, chosen,
            reassign: reassign), success: 'Responsable actualizado');
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref,
      RepairStatus next) async {
    final approved = await confirmAction(context, 'Cambiar estado',
      next == RepairStatus.cancelled
          ? 'La orden quedará cancelada. Los repuestos ya consumidos NO se reintegrarán automáticamente.'
          : '¿Confirmás el cambio de estado a "${next.label}"?');
    if (!approved || !context.mounted) return;
    await _perform(context,
      () => ref.read(orderCommandsProvider.notifier).setStatus(orderId, next),
      success: 'Estado: ${next.label}');
  }

  Future<void> _editDiagnosis(BuildContext context, WidgetRef ref, String initial) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => DiagnosisEditDialog(initialDiagnosis: initial),
    );
    if (result == null || !context.mounted) return;
    await _perform(context,
        () => ref.read(orderCommandsProvider.notifier).setDiagnosis(orderId, result));
  }

  Future<void> _addLabor(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String description, int cents})>(
      context: context,
      builder: (_) => const LaborEditDialog(),
    );
    if (result == null || !context.mounted) return;
    await _perform(context, () => ref.read(orderCommandsProvider.notifier)
        .addLabor(orderId, result.description, result.cents));
  }

  Future<void> _addUsedPart(BuildContext context, WidgetRef ref) async {
    final parts = ref.read(partsProvider).valueOrNull ?? <SparePart>[];
    if (parts.isEmpty) {
      notifyResult(context, const DomainException('Primero registrá repuestos en Inventario.'));
      return;
    }
    final result = await showDialog<({int partId, int qty})>(
      context: context,
      builder: (_) => UsedPartEditDialog(parts: parts),
    );
    if (result == null || !context.mounted) return;
    await _perform(context, () => ref.read(orderCommandsProvider.notifier)
        .usePart(orderId, result.partId, result.qty), success: 'Repuesto descontado del stock');
  }

  Future<void> _deleteLabor(BuildContext context, WidgetRef ref, int id) async {
    if (!(await confirmAction(context, 'Eliminar trabajo',
        '¿Querés quitar este costo de mano de obra?')) || !context.mounted) return;
    await _perform(context,
        () => ref.read(orderCommandsProvider.notifier).removeLabor(orderId, id));
  }

  Future<void> _deleteUsage(BuildContext context, WidgetRef ref, int id) async {
    if (!(await confirmAction(context, 'Quitar repuesto',
        'El consumo se eliminará y la cantidad volverá al inventario.')) || !context.mounted) return;
    await _perform(context,
        () => ref.read(orderCommandsProvider.notifier).removeUsedPart(orderId, id),
        success: 'Stock devuelto al inventario');
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine(this.label, this.cents);
  final String label;
  final int cents;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label)),
    Text(money(cents)),
  ]);
}
