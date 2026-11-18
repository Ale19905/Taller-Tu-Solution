import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../../core/formatters.dart';

Color statusColor(RepairStatus status) => switch (status) {
      RepairStatus.received => const Color(0xFF4D79A2),
      RepairStatus.repairing => const Color(0xFFA36E21),
      RepairStatus.ready => const Color(0xFF247E65),
      RepairStatus.delivered => const Color(0xFF6C737A),
      RepairStatus.cancelled => const Color(0xFFAB5656),
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final RepairStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(status.label, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: Colors.blueGrey.shade300),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600)),
          ]),
        ),
      );
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.item, required this.onTap});
  final OrderOverview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Orden #${item.order.id}',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                StatusChip(item.status),
              ]),
              const SizedBox(height: 9),
              Text(item.deviceTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(item.customer.name),
              const SizedBox(height: 8),
              Text(item.order.reportedIssue,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.blueGrey.shade600)),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 8, children: [
                IconText(Icons.person_outline,
                    item.technician?.name ?? 'Sin asignar'),
                IconText(Icons.schedule_outlined,
                    dateLabel(item.order.createdAt)),
              ]),
            ]),
          ),
        ),
      );
}

class IconText extends StatelessWidget {
  const IconText(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.blueGrey.shade600),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12,
              color: Colors.blueGrey.shade700)),
        ]);
}

Future<bool> confirmAction(BuildContext context, String title, String description) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Volver')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar')),
          ],
        ),
      ) ?? false;
}

void notifyResult(BuildContext context, Object? error, {String success = 'Cambios guardados'}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error == null ? success :
        (error is DomainException ? error.message : 'Ocurrió un error: $error')),
  ));
}

InputDecoration fieldDecoration(String label, {String? hint}) =>
    InputDecoration(labelText: label, hintText: hint);
