import '../data/workshop_database.dart';

/// Every order has one of these exact, persisted workflow states.
enum RepairStatus {
  received('recibida', 'Recibida'),
  repairing('en_reparacion', 'En reparación'),
  ready('lista', 'Lista'),
  delivered('entregada', 'Entregada'),
  cancelled('cancelada', 'Cancelada');

  const RepairStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static RepairStatus fromDb(String value) =>
      RepairStatus.values.firstWhere((status) => status.dbValue == value);
  bool get isOpen => this == received || this == repairing || this == ready;
}

class DomainException implements Exception {
  const DomainException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrderOverview {
  const OrderOverview({
    required this.order,
    required this.device,
    required this.customer,
    required this.technician,
  });
  final RepairOrder order;
  final Device device;
  final Customer customer;
  final Technician? technician;

  RepairStatus get status => RepairStatus.fromDb(order.status);
  String get deviceTitle => '${device.brand} ${device.model}';
}

class UsedPartOverview {
  const UsedPartOverview({required this.usage, required this.part});
  final PartUsage usage;
  final SparePart part;
  int get totalCents => usage.quantity * usage.unitPriceCents;
}

class NewOrderDraft {
  const NewOrderDraft({
    this.customerId,
    this.deviceId,
    this.customerName = '',
    this.customerPhone = '',
    this.deviceType = 'Celular',
    this.brand = '',
    this.model = '',
    this.serialNumber = '',
    required this.issue,
  });

  final int? customerId;
  final int? deviceId;
  final String customerName;
  final String customerPhone;
  final String deviceType;
  final String brand;
  final String model;
  final String serialNumber;
  final String issue;
}
