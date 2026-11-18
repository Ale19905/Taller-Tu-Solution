import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'workshop_database.g.dart';

/// Offline-first normalized model. Amounts are integer cents, not floating point.
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().withLength(min: 1, max: 40)();
}

class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get type => text()();
  TextColumn get brand => text()();
  TextColumn get model => text()();
  TextColumn get serialNumber => text().unique()();
}

class Technicians extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
}

class RepairOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer().references(Devices, #id)();
  IntColumn get technicianId => integer().nullable().references(Technicians, #id)();
  TextColumn get reportedIssue => text()();
  TextColumn get diagnosis => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('recibida'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

class LaborEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(RepairOrders, #id)();
  TextColumn get description => text()();
  IntColumn get costCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class SpareParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  IntColumn get unitPriceCents => integer()();
  IntColumn get stock => integer()();
  IntColumn get minimumStock => integer()();
}

class PartUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(RepairOrders, #id)();
  IntColumn get partId => integer().references(SpareParts, #id)();
  IntColumn get quantity => integer()();
  // Keep historical part identity even if the catalog is later renamed.
  TextColumn get partName => text()();
  TextColumn get partCode => text()();
  // Sale price is captured at consumption time so history cannot change.
  IntColumn get unitPriceCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get partId => integer().references(SpareParts, #id)();
  IntColumn get delta => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [
  Customers,
  Devices,
  Technicians,
  RepairOrders,
  LaborEntries,
  SpareParts,
  PartUsages,
  StockMovements,
])
class WorkshopDatabase extends _$WorkshopDatabase {
  WorkshopDatabase() : super(_openConnection());
  WorkshopDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          // The shop has exactly three technicians. Names can be edited later.
          for (var i = 1; i <= 3; i++) {
            await into(technicians).insert(
              TechniciansCompanion.insert(name: 'Técnico $i'),
            );
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, 'tu_solution.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
