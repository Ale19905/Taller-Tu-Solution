import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/workshop_database.dart';
import '../../domain/entities.dart';
import '../viewmodels/providers.dart';
import '../viewmodels/commands.dart';
import '../widgets/common.dart';
import 'order_detail_page.dart';

class NewOrderPage extends ConsumerStatefulWidget {
  const NewOrderPage({super.key});

  @override
  ConsumerState<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends ConsumerState<NewOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _issue = TextEditingController();
  int? _customerId;
  int? _deviceId;
  String _deviceType = 'Celular';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_customerName, _customerPhone, _brand, _model, _serial, _issue]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? <Customer>[];
    final devices = ref.watch(devicesProvider).valueOrNull ?? <Device>[];
    final customerDevices = devices.where((d) => d.customerId == _customerId).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: Form(key: _formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          const SectionHeader('1. Cliente'),
          DropdownButtonFormField<int?>(
            initialValue: _customerId,
            isExpanded: true,
            decoration: fieldDecoration('Cliente registrado'),
            items: [
              const DropdownMenuItem<int?>(value: null,
                  child: Text('+ Nuevo cliente')),
              ...customers.map((c) => DropdownMenuItem<int?>(
                value: c.id, child: Text('${c.name} · ${c.phone}',
                    overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() { _customerId = value; _deviceId = null; }),
          ),
          if (_customerId == null) ...[
            const SizedBox(height: 12),
            TextFormField(controller: _customerName,
              decoration: fieldDecoration('Nombre y apellido'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _customerPhone,
              keyboardType: TextInputType.phone,
              decoration: fieldDecoration('Teléfono'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Obligatorio' : null),
          ],
          const SectionHeader('2. Equipo'),
          if (_customerId != null)
            DropdownButtonFormField<int?>(
              key: ValueKey(_customerId),
              initialValue: _deviceId,
              isExpanded: true,
              decoration: fieldDecoration('Equipo del cliente'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('+ Nuevo equipo')),
                ...customerDevices.map((d) => DropdownMenuItem<int?>(
                    value: d.id, child: Text('${d.brand} ${d.model} · ${d.serialNumber}',
                        overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (value) => setState(() => _deviceId = value),
            ),
          if (_deviceId == null) ...[
            if (_customerId != null) const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _deviceType,
              decoration: fieldDecoration('Tipo de equipo'),
              items: ['Celular', 'Tablet', 'Laptop'].map((value) =>
                DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _deviceType = value ?? 'Celular'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _brand, decoration: fieldDecoration('Marca'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _model, decoration: fieldDecoration('Modelo'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _serial,
                decoration: fieldDecoration('Número de serie único'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null),
          ],
          const SectionHeader('3. Recepción'),
          TextFormField(
            controller: _issue,
            maxLines: 4,
            decoration: fieldDecoration('Falla reportada por el cliente'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Describí la falla' : null,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 17, height: 17,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: const Text('Registrar orden'),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(orderCommandsProvider.notifier).createOrder(NewOrderDraft(
        customerId: _customerId, deviceId: _deviceId,
        customerName: _customerName.text, customerPhone: _customerPhone.text,
        deviceType: _deviceType, brand: _brand.text, model: _model.text,
        serialNumber: _serial.text, issue: _issue.text,
      ));
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute<void>(
          builder: (_) => OrderDetailPage(orderId: id)));
    } catch (e) {
      notifyResult(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
