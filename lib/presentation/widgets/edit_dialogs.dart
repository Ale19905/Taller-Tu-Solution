import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/workshop_database.dart';
import 'common.dart';

// Los controladores pertenecen al State del diálogo, no a la función que
// llama showDialog. Su Future se completa antes de que termine la animación
// de salida; liberarlos justo después del await puede romper el árbol Flutter.

class DiagnosisEditDialog extends StatefulWidget {
  const DiagnosisEditDialog({super.key, required this.initialDiagnosis});

  final String initialDiagnosis;

  @override
  State<DiagnosisEditDialog> createState() => _DiagnosisEditDialogState();
}

class _DiagnosisEditDialogState extends State<DiagnosisEditDialog> {
  late final TextEditingController _diagnosis;

  @override
  void initState() {
    super.initState();
    _diagnosis = TextEditingController(text: widget.initialDiagnosis);
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Diagnóstico'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _diagnosis,
              maxLines: 5,
              autofocus: true,
              decoration: fieldDecoration('Observaciones técnicas'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _diagnosis.text),
            child: const Text('Guardar'),
          ),
        ],
      );
}

class LaborEditDialog extends StatefulWidget {
  const LaborEditDialog({super.key});

  @override
  State<LaborEditDialog> createState() => _LaborEditDialogState();
}

class _LaborEditDialogState extends State<LaborEditDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _cost = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Agregar mano de obra'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _description,
                    decoration: fieldDecoration('Trabajo realizado'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: fieldDecoration('Costo (ej. 1250,50)'),
                    validator: (value) => (parseMoney(value ?? '') ?? -1) < 0
                        ? 'Costo inválido'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, (
                  description: _description.text.trim(),
                  cents: parseMoney(_cost.text)!,
                ));
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      );
}

class UsedPartEditDialog extends StatefulWidget {
  const UsedPartEditDialog({super.key, required this.parts});

  final List<SparePart> parts;

  @override
  State<UsedPartEditDialog> createState() => _UsedPartEditDialogState();
}

class _UsedPartEditDialogState extends State<UsedPartEditDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  int? _selectedPartId;

  @override
  void initState() {
    super.initState();
    _selectedPartId = widget.parts.isEmpty ? null : widget.parts.first.id;
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Usar repuesto'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedPartId,
                    decoration: fieldDecoration('Repuesto'),
                    items: widget.parts.map((part) => DropdownMenuItem<int>(
                      value: part.id,
                      child: Text('${part.name} (${part.stock} disp.)',
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedPartId = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration('Cantidad'),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Ingresá una cantidad positiva'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate() && _selectedPartId != null) {
                Navigator.pop(context, (
                  partId: _selectedPartId!,
                  qty: int.parse(_quantity.text),
                ));
              }
            },
            child: const Text('Registrar uso'),
          ),
        ],
      );
}

class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key, required this.part});

  final SparePart part;

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  bool _isEntry = true;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Modificar stock · ${widget.part.code}'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Entrada')),
                      ButtonSegment(value: false, label: Text('Salida')),
                    ],
                    selected: {_isEntry},
                    onSelectionChanged: (value) => setState(
                      () => _isEntry = value.first,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration('Cantidad'),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Ingresá un entero positivo'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    decoration: fieldDecoration('Motivo (compra, ajuste, etc.)'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text('Existencia actual: ${widget.part.stock}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                final quantity = int.parse(_quantity.text);
                Navigator.pop(context, (
                  delta: _isEntry ? quantity : -quantity,
                  reason: _reason.text.trim(),
                ));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
}

class TechnicianNameDialog extends StatefulWidget {
  const TechnicianNameDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<TechnicianNameDialog> createState() => _TechnicianNameDialogState();
}

class _TechnicianNameDialogState extends State<TechnicianNameDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nombre del técnico'),
        content: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _name,
              autofocus: true,
              decoration: fieldDecoration('Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _name.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      );
}
