import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/workshop_database.dart';
import '../../data/workshop_repository.dart';
import '../../domain/entities.dart';

/// MVVM: Views listen to these reactive view-model providers; repositories
/// own all business rules, while the Drift database is the persistence model.
final databaseProvider = Provider<WorkshopDatabase>((ref) {
  final database = WorkshopDatabase();
  ref.onDispose(() { database.close(); });
  return database;
});

final repositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(ref.watch(databaseProvider)),
);

final techniciansProvider = StreamProvider<List<Technician>>(
  (ref) => ref.watch(repositoryProvider).watchTechnicians(),
);
final customersProvider = StreamProvider<List<Customer>>(
  (ref) => ref.watch(repositoryProvider).watchCustomers(),
);
final devicesProvider = StreamProvider<List<Device>>(
  (ref) => ref.watch(repositoryProvider).watchDevices(),
);
final ordersProvider = StreamProvider<List<OrderOverview>>(
  (ref) => ref.watch(repositoryProvider).watchOrders(),
);
final partsProvider = StreamProvider<List<SparePart>>(
  (ref) => ref.watch(repositoryProvider).watchParts(),
);
final orderProvider = StreamProvider.autoDispose.family<RepairOrder?, int>(
  (ref, id) => ref.watch(repositoryProvider).watchOrder(id),
);
final laborProvider = StreamProvider.autoDispose.family<List<LaborEntry>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchLabor(id),
);
final usedPartsProvider =
    StreamProvider.autoDispose.family<List<UsedPartOverview>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchUsedParts(id),
);
final movementsProvider =
    StreamProvider.autoDispose.family<List<StockMovement>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchMovements(id),
);
