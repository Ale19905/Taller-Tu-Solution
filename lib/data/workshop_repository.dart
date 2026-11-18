import 'package:drift/drift.dart';

import '../domain/entities.dart';
import 'workshop_database.dart';

class WorkshopRepository {
  const WorkshopRepository(this.db);
  final WorkshopDatabase db;

  Stream<List<Technician>> watchTechnicians() =>
      (db.select(db.technicians)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Stream<List<Customer>> watchCustomers() =>
      (db.select(db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<Device>> watchDevices() =>
      (db.select(db.devices)..orderBy([(t) => OrderingTerm.asc(t.brand)]))
          .watch();

  Stream<List<SparePart>> watchParts() =>
      (db.select(db.spareParts)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<StockMovement>> watchMovements(int partId) =>
      (db.select(db.stockMovements)
            ..where((t) => t.partId.equals(partId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Stream<List<OrderOverview>> watchOrders() {
    final statement = db.select(db.repairOrders).join([
      innerJoin(db.devices, db.devices.id.equalsExp(db.repairOrders.deviceId)),
      innerJoin(db.customers, db.customers.id.equalsExp(db.devices.customerId)),
      leftOuterJoin(db.technicians,
          db.technicians.id.equalsExp(db.repairOrders.technicianId)),
    ]);
    statement.orderBy([OrderingTerm.desc(db.repairOrders.createdAt)]);
    return statement.watch().map((rows) => rows
        .map((row) => OrderOverview(
              order: row.readTable(db.repairOrders),
              device: row.readTable(db.devices),
              customer: row.readTable(db.customers),
              technician: row.readTableOrNull(db.technicians),
            ))
        .toList());
  }

  Stream<RepairOrder?> watchOrder(int id) =>
      (db.select(db.repairOrders)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Stream<List<LaborEntry>> watchLabor(int orderId) =>
      (db.select(db.laborEntries)
            ..where((t) => t.orderId.equals(orderId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Stream<List<UsedPartOverview>> watchUsedParts(int orderId) {
    final query = db.select(db.partUsages).join([
      innerJoin(db.spareParts,
          db.spareParts.id.equalsExp(db.partUsages.partId)),
    ])..where(db.partUsages.orderId.equals(orderId));
    query.orderBy([OrderingTerm.asc(db.partUsages.createdAt)]);
    return query.watch().map((rows) => rows
        .map((row) => UsedPartOverview(
              usage: row.readTable(db.partUsages),
              part: row.readTable(db.spareParts),
            ))
        .toList());
  }

  Future<int> createOrder(NewOrderDraft draft) => db.transaction(() async {
        if (draft.issue.trim().isEmpty) {
          throw const DomainException('Indicá la falla reportada.');
        }
        int customerId;
        if (draft.customerId != null) {
          final existing = await (db.select(db.customers)
                ..where((t) => t.id.equals(draft.customerId!)))
              .getSingleOrNull();
          if (existing == null) {
            throw const DomainException('El cliente seleccionado ya no existe.');
          }
          customerId = existing.id;
        } else {
          if (draft.customerName.trim().isEmpty ||
              draft.customerPhone.trim().isEmpty) {
            throw const DomainException('Completá nombre y teléfono del cliente.');
          }
          customerId = await db.into(db.customers).insert(
                CustomersCompanion.insert(
                  name: draft.customerName.trim(),
                  phone: draft.customerPhone.trim(),
                ),
              );
        }

        int deviceId;
        if (draft.deviceId != null) {
          final existing = await (db.select(db.devices)
                ..where((t) => t.id.equals(draft.deviceId!)))
              .getSingleOrNull();
          if (existing == null || existing.customerId != customerId) {
            throw const DomainException('El equipo no pertenece al cliente seleccionado.');
          }
          deviceId = existing.id;
        } else {
          if ([draft.brand, draft.model, draft.serialNumber]
              .any((value) => value.trim().isEmpty)) {
            throw const DomainException('Completá marca, modelo y número de serie.');
          }
          final serial = draft.serialNumber.trim().toUpperCase();
          final duplicate = await (db.select(db.devices)
                ..where((t) => t.serialNumber.equals(serial)))
              .getSingleOrNull();
          if (duplicate != null) {
            throw const DomainException(
                'Ese número de serie ya está registrado. Elegí el cliente y equipo existentes.');
          }
          deviceId = await db.into(db.devices).insert(
                DevicesCompanion.insert(
                  customerId: customerId,
                  type: draft.deviceType,
                  brand: draft.brand.trim(),
                  model: draft.model.trim(),
                  serialNumber: serial,
                ),
              );
        }
        final now = DateTime.now();
        return db.into(db.repairOrders).insert(RepairOrdersCompanion.insert(
              deviceId: deviceId,
              reportedIssue: draft.issue.trim(),
              createdAt: now,
              updatedAt: now,
            ));
      });

  Future<void> renameTechnician(int id, String name) async {
    if (name.trim().isEmpty) {
      throw const DomainException('El nombre no puede quedar vacío.');
    }
    await (db.update(db.technicians)..where((t) => t.id.equals(id)))
        .write(TechniciansCompanion(name: Value(name.trim())));
  }

  Future<void> assignOrder(int orderId, int technicianId,
      {bool reassign = false}) => db.transaction(() async {
        final order = await _requireOrder(orderId);
        if (!RepairStatus.fromDb(order.status).isOpen ||
            order.status == RepairStatus.ready.dbValue) {
          throw const DomainException('Solo se puede tomar una orden recibida o en reparación.');
        }
        final tech = await (db.select(db.technicians)
              ..where((t) => t.id.equals(technicianId)))
            .getSingleOrNull();
        if (tech == null) {
          throw const DomainException('El técnico ya no existe.');
        }
        if (order.technicianId != null &&
            order.technicianId != technicianId &&
            !reassign) {
          throw const DomainException('Esta orden ya fue tomada por otro técnico.');
        }
        if (reassign && order.technicianId == null) {
          throw const DomainException('La orden aún no tiene un responsable.');
        }
        await (db.update(db.repairOrders)..where((t) => t.id.equals(orderId)))
            .write(RepairOrdersCompanion(
          technicianId: Value(technicianId),
          status: Value(RepairStatus.repairing.dbValue),
          updatedAt: Value(DateTime.now()),
        ));
      });

  Future<void> setStatus(int id, RepairStatus next) => db.transaction(() async {
        final order = await _requireOrder(id);
        final current = RepairStatus.fromDb(order.status);
        final allowed = switch (current) {
          RepairStatus.received => {RepairStatus.cancelled},
          RepairStatus.repairing => {RepairStatus.ready, RepairStatus.cancelled},
          RepairStatus.ready => {RepairStatus.delivered, RepairStatus.cancelled},
          RepairStatus.delivered || RepairStatus.cancelled => <RepairStatus>{},
        };
        if (!allowed.contains(next)) {
          throw DomainException('No se permite pasar de ${current.label} a ${next.label}.');
        }
        await (db.update(db.repairOrders)..where((t) => t.id.equals(id)))
            .write(RepairOrdersCompanion(
          status: Value(next.dbValue),
          updatedAt: Value(DateTime.now()),
          closedAt: next == RepairStatus.delivered || next == RepairStatus.cancelled
              ? Value(DateTime.now())
              : const Value.absent(),
        ));
      });

  Future<void> setDiagnosis(int orderId, String diagnosis) async {
    final order = await _requireOrder(orderId);
    if (!RepairStatus.fromDb(order.status).isOpen) {
      throw const DomainException('No se puede modificar una orden cerrada.');
    }
    await (db.update(db.repairOrders)..where((t) => t.id.equals(orderId)))
        .write(RepairOrdersCompanion(
      diagnosis: Value(diagnosis.trim()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> addLabor(int orderId, String description, int costCents) =>
      db.transaction(() async {
        await _requireRepairing(orderId);
        if (description.trim().isEmpty || costCents < 0) {
          throw const DomainException('Revisá la descripción y el costo de mano de obra.');
        }
        await db.into(db.laborEntries).insert(LaborEntriesCompanion.insert(
              orderId: orderId,
              description: description.trim(),
              costCents: costCents,
              createdAt: DateTime.now(),
            ));
        await _touchOrder(orderId);
      });

  Future<void> removeLabor(int orderId, int laborId) => db.transaction(() async {
        await _requireRepairing(orderId);
        await (db.delete(db.laborEntries)
              ..where((t) => t.id.equals(laborId) & t.orderId.equals(orderId)))
            .go();
        await _touchOrder(orderId);
      });

  Future<void> addPart({
    required String name,
    required String code,
    required int priceCents,
    required int initialStock,
    required int minimumStock,
  }) => db.transaction(() async {
        if (name.trim().isEmpty || code.trim().isEmpty ||
            priceCents < 0 || initialStock < 0 || minimumStock < 0) {
          throw const DomainException('Revisá los datos del repuesto y sus existencias.');
        }
        final normalizedCode = code.trim().toUpperCase();
        await _assertUniqueCode(normalizedCode);
        final id = await db.into(db.spareParts).insert(SparePartsCompanion.insert(
              name: name.trim(),
              code: normalizedCode,
              unitPriceCents: priceCents,
              stock: initialStock,
              minimumStock: minimumStock,
            ));
        if (initialStock > 0) {
          await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
                partId: id,
                delta: initialStock,
                reason: 'Stock inicial',
                createdAt: DateTime.now(),
              ));
        }
      });

  Future<void> editPart({
    required int id,
    required String name,
    required String code,
    required int priceCents,
    required int minimumStock,
  }) => db.transaction(() async {
        if (name.trim().isEmpty || code.trim().isEmpty ||
            priceCents < 0 || minimumStock < 0) {
          throw const DomainException('Revisá los datos del repuesto.');
        }
        final existing = await _requirePart(id);
        final normalized = code.trim().toUpperCase();
        if (existing.code != normalized) {
          await _assertUniqueCode(normalized);
        }
        await (db.update(db.spareParts)..where((t) => t.id.equals(id)))
            .write(SparePartsCompanion(
          name: Value(name.trim()),
          code: Value(normalized),
          unitPriceCents: Value(priceCents),
          minimumStock: Value(minimumStock),
        ));
      });

  Future<void> adjustStock(int partId, int delta, String reason) =>
      db.transaction(() async {
        if (delta == 0 || reason.trim().isEmpty) {
          throw const DomainException('Indicá una cantidad distinta de cero y un motivo.');
        }
        final part = await _requirePart(partId);
        if (part.stock + delta < 0) {
          throw const DomainException('La existencia no puede ser negativa.');
        }
        await _changeStock(partId, delta, reason.trim());
      });

  Future<void> usePart(int orderId, int partId, int quantity) =>
      db.transaction(() async {
        await _requireRepairing(orderId);
        if (quantity <= 0) {
          throw const DomainException('La cantidad debe ser mayor a cero.');
        }
        final part = await _requirePart(partId);
        if (part.stock < quantity) {
          throw DomainException('Stock insuficiente: hay ${part.stock} unidades disponibles.');
        }
        await db.into(db.partUsages).insert(PartUsagesCompanion.insert(
              orderId: orderId,
              partId: partId,
              quantity: quantity,
              partName: part.name,
              partCode: part.code,
              unitPriceCents: part.unitPriceCents,
              createdAt: DateTime.now(),
            ));
        await _changeStock(partId, -quantity, 'Uso en orden #$orderId');
        await _touchOrder(orderId);
      });

  Future<void> removeUsedPart(int orderId, int usageId) => db.transaction(() async {
        await _requireRepairing(orderId);
        final usage = await (db.select(db.partUsages)
              ..where((t) => t.id.equals(usageId) & t.orderId.equals(orderId)))
            .getSingleOrNull();
        if (usage == null) {
          throw const DomainException('El consumo ya no existe.');
        }
        await (db.delete(db.partUsages)..where((t) => t.id.equals(usageId))).go();
        await _changeStock(usage.partId, usage.quantity,
            'Devolución desde orden #$orderId');
        await _touchOrder(orderId);
      });

  Future<RepairOrder> _requireOrder(int id) async {
    final found = await (db.select(db.repairOrders)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (found == null) throw const DomainException('No se encontró la orden.');
    return found;
  }

  Future<void> _requireRepairing(int orderId) async {
    final order = await _requireOrder(orderId);
    if (order.status != RepairStatus.repairing.dbValue ||
        order.technicianId == null) {
      throw const DomainException('Primero un técnico debe tomar la orden.');
    }
  }

  Future<SparePart> _requirePart(int id) async {
    final part = await (db.select(db.spareParts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (part == null) throw const DomainException('No se encontró el repuesto.');
    return part;
  }

  Future<void> _assertUniqueCode(String code) async {
    final existing = await (db.select(db.spareParts)
          ..where((t) => t.code.equals(code)))
        .getSingleOrNull();
    if (existing != null) throw const DomainException('Ya existe ese código de repuesto.');
  }

  Future<void> _changeStock(int partId, int delta, String reason) async {
    // Called inside a transaction: the stock and movement must commit together.
    final current = await _requirePart(partId);
    if (current.stock + delta < 0) {
      throw const DomainException('No hay stock suficiente.');
    }
    await (db.update(db.spareParts)..where((t) => t.id.equals(partId)))
        .write(SparePartsCompanion(stock: Value(current.stock + delta)));
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
          partId: partId,
          delta: delta,
          reason: reason,
          createdAt: DateTime.now(),
        ));
  }

  Future<void> _touchOrder(int id) async {
    await (db.update(db.repairOrders)..where((t) => t.id.equals(id)))
        .write(RepairOrdersCompanion(updatedAt: Value(DateTime.now())));
  }
}
