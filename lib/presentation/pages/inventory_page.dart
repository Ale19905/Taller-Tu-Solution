import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/workshop_database.dart';
import '../viewmodels/providers.dart';
import '../viewmodels/commands.dart';
import '../widgets/common.dart';
import '../widgets/edit_dialogs.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String _query = '';
  bool _onlyLow = false;

  @override
  Widget build(BuildContext context) {
    final asyncParts = ref.watch(partsProvider);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Column(children: [
        TextField(
          decoration: fieldDecoration('Buscar por nombre o código')
            .copyWith(prefixIcon: const Icon(Icons.search)),
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
        ),
        Row(children: [
          FilterChip(
            label: const Text('Solo stock bajo'),
            selected: _onlyLow,
            onSelected: (value) => setState(() => _onlyLow = value)),
          const Spacer(),
          TextButton.icon(onPressed: () => _editPart(context),
            icon: const Icon(Icons.add), label: const Text('Nuevo repuesto')),
        ]),
      ])),
      Expanded(child: asyncParts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyMessage('No se pudo cargar el inventario: $e'),
        data: (parts) {
          final filtered = parts.where((p) =>
              (!_onlyLow || p.stock <= p.minimumStock) &&
              '${p.name} ${p.code}'.toLowerCase().contains(_query)).toList();
          if (filtered.isEmpty) return const EmptyMessage(
            'No hay repuestos para mostrar. Agregá el primero.',
            icon: Icons.inventory_2_outlined);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            children: [for (final part in filtered) _PartCard(
              part: part,
              onEdit: () => _editPart(context, part: part),
              onAdjust: () => _adjustStock(context, part),
              onMovements: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => _MovementsPage(part: part))),
            )]);
        },
      )),
    ]);
  }

  Future<void> _editPart(BuildContext context, {SparePart? part}) async {
    final data = await showDialog<_PartDraft>(context: context,
        builder: (_) => _PartFormDialog(part: part));
    if (data == null || !context.mounted) return;
    try {
      if (part == null) {
        await ref.read(inventoryCommandsProvider.notifier).addPart(
          name: data.name, code: data.code, priceCents: data.priceCents,
          initialStock: data.initialStock, minimumStock: data.minimumStock);
      } else {
        await ref.read(inventoryCommandsProvider.notifier).editPart(
          id: part.id, name: data.name, code: data.code,
          priceCents: data.priceCents, minimumStock: data.minimumStock);
      }
      if (context.mounted) notifyResult(context, null);
    } catch (e) {
      if (context.mounted) notifyResult(context, e);
    }
  }

  Future<void> _adjustStock(BuildContext context, SparePart part) async {
    final data = await showDialog<({int delta, String reason})>(
      context: context,
      builder: (_) => StockAdjustmentDialog(part: part),
    );
    if (data == null || !context.mounted) return;
    try {
      await ref.read(inventoryCommandsProvider.notifier).adjustStock(part.id, data.delta, data.reason);
      if (context.mounted) notifyResult(context, null, success: 'Stock actualizado');
    } catch (e) {
      if (context.mounted) notifyResult(context, e);
    }
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part, required this.onEdit,
      required this.onAdjust, required this.onMovements});
  final SparePart part;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onMovements;

  @override
  Widget build(BuildContext context) {
    final low = part.stock <= part.minimumStock;
    return Card(margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(part.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            if (low) const Chip(label: Text('Stock bajo'),
              avatar: Icon(Icons.warning_amber_rounded, color: Color(0xFFB26C26), size: 17)),
          ]),
          Text('Código: ${part.code} · Precio: ${money(part.unitPriceCents)}'),
          const SizedBox(height: 12),
          Row(children: [
            Text('${part.stock}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: low ? const Color(0xFFB26C26) : null)),
            const SizedBox(width: 8),
            Text('unidades · mínimo ${part.minimumStock}',
              style: TextStyle(color: Colors.blueGrey.shade700)),
          ]),
          const Divider(height: 20),
          Wrap(spacing: 4, children: [
            TextButton.icon(onPressed: onAdjust, icon: const Icon(Icons.tune),
                label: const Text('Ajustar')),
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar')),
            TextButton.icon(onPressed: onMovements,
                icon: const Icon(Icons.history), label: const Text('Movimientos')),
          ]),
        ],
      )));
  }
}

class _PartDraft {
  const _PartDraft({required this.name, required this.code,
    required this.priceCents, required this.initialStock,
    required this.minimumStock});
  final String name;
  final String code;
  final int priceCents;
  final int initialStock;
  final int minimumStock;
}

class _PartFormDialog extends StatefulWidget {
  const _PartFormDialog({this.part});
  final SparePart? part;
  @override
  State<_PartFormDialog> createState() => _PartFormDialogState();
}

class _PartFormDialogState extends State<_PartFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _min;

  @override
  void initState() {
    super.initState();
    final part = widget.part;
    _name = TextEditingController(text: part?.name ?? '');
    _code = TextEditingController(text: part?.code ?? '');
    _price = TextEditingController(text: part == null ? '' :
      (part.unitPriceCents / 100).toStringAsFixed(2).replaceAll('.', ','));
    _stock = TextEditingController(text: '0');
    _min = TextEditingController(text: '${part?.minimumStock ?? 2}');
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _price, _stock, _min]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.part == null ? 'Nuevo repuesto' : 'Editar repuesto'),
    content: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Form(key: _form, child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _name, decoration: fieldDecoration('Nombre'),
          validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _code, decoration: fieldDecoration('Código único'),
          validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _price, keyboardType: TextInputType.number,
          decoration: fieldDecoration('Precio unitario'),
          validator: (v) => (parseMoney(v ?? '') ?? -1) < 0 ? 'Monto inválido' : null),
        const SizedBox(height: 10),
        if (widget.part == null) ...[
          TextFormField(controller: _stock, keyboardType: TextInputType.number,
            decoration: fieldDecoration('Stock inicial'),
            validator: _nonnegative),
          const SizedBox(height: 10),
        ],
        TextFormField(controller: _min, keyboardType: TextInputType.number,
          decoration: fieldDecoration('Avisar cuando queden ≤'),
          validator: _nonnegative),
        if (widget.part != null)
          const Padding(padding: EdgeInsets.only(top: 10),
            child: Text('Las existencias se cambian desde «Ajustar», para dejar registro.')),
      ],
    )))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(context, _PartDraft(
            name: _name.text, code: _code.text,
            priceCents: parseMoney(_price.text)!,
            initialStock: int.tryParse(_stock.text) ?? 0,
            minimumStock: int.parse(_min.text),
          ));
        }
      }, child: const Text('Guardar')),
    ],
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Obligatorio' : null;
  String? _nonnegative(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n < 0 ? 'Ingresá un entero mayor o igual a cero' : null;
  }
}

class _MovementsPage extends ConsumerWidget {
  const _MovementsPage({required this.part});
  final SparePart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(movementsProvider(part.id));
    return Scaffold(appBar: AppBar(title: Text('Movimientos · ${part.code}')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyMessage('No se pudo cargar el historial: $e'),
        data: (moves) => moves.isEmpty
          ? const EmptyMessage('Sin movimientos registrados.')
          : ListView(padding: const EdgeInsets.all(16), children: [
            for (final m in moves) Card(child: ListTile(
              leading: Icon(m.delta > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                color: m.delta > 0 ? Colors.green.shade700 : Colors.orange.shade700),
              title: Text(m.reason),
              subtitle: Text(dateLabel(m.createdAt)),
              trailing: Text('${m.delta > 0 ? '+' : ''}${m.delta}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
      ),
    );
  }
}
