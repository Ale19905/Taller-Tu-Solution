import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/workshop_repository.dart';
import '../../domain/entities.dart';
import 'providers.dart';

/// Command view models mediate every mutation requested by a View.
/// The database and repository are never accessed directly from widgets.
abstract class CommandViewModel extends StateNotifier<AsyncValue<void>> {
  CommandViewModel() : super(const AsyncData(null));

  Future<T> execute<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

class OrderCommands extends CommandViewModel {
  OrderCommands(this._repo);
  final WorkshopRepository _repo;

  Future<int> createOrder(NewOrderDraft draft) =>
      execute(() => _repo.createOrder(draft));
  Future<void> assignOrder(int orderId, int technicianId, {bool reassign = false}) =>
      execute(() => _repo.assignOrder(orderId, technicianId, reassign: reassign));
  Future<void> setStatus(int id, RepairStatus status) =>
      execute(() => _repo.setStatus(id, status));
  Future<void> setDiagnosis(int id, String diagnosis) =>
      execute(() => _repo.setDiagnosis(id, diagnosis));
  Future<void> addLabor(int id, String description, int costCents) =>
      execute(() => _repo.addLabor(id, description, costCents));
  Future<void> removeLabor(int orderId, int laborId) =>
      execute(() => _repo.removeLabor(orderId, laborId));
  Future<void> usePart(int orderId, int partId, int quantity) =>
      execute(() => _repo.usePart(orderId, partId, quantity));
  Future<void> removeUsedPart(int orderId, int usageId) =>
      execute(() => _repo.removeUsedPart(orderId, usageId));
}

class InventoryCommands extends CommandViewModel {
  InventoryCommands(this._repo);
  final WorkshopRepository _repo;

  Future<void> addPart({required String name, required String code,
    required int priceCents, required int initialStock,
    required int minimumStock}) => execute(() => _repo.addPart(
      name: name, code: code, priceCents: priceCents,
      initialStock: initialStock, minimumStock: minimumStock));

  Future<void> editPart({required int id, required String name,
    required String code, required int priceCents,
    required int minimumStock}) => execute(() => _repo.editPart(
      id: id, name: name, code: code,
      priceCents: priceCents, minimumStock: minimumStock));

  Future<void> adjustStock(int partId, int delta, String reason) =>
      execute(() => _repo.adjustStock(partId, delta, reason));
}

class TechnicianCommands extends CommandViewModel {
  TechnicianCommands(this._repo);
  final WorkshopRepository _repo;

  Future<void> renameTechnician(int id, String name) =>
      execute(() => _repo.renameTechnician(id, name));
}

final orderCommandsProvider =
    StateNotifierProvider<OrderCommands, AsyncValue<void>>(
  (ref) => OrderCommands(ref.watch(repositoryProvider)),
);
final inventoryCommandsProvider =
    StateNotifierProvider<InventoryCommands, AsyncValue<void>>(
  (ref) => InventoryCommands(ref.watch(repositoryProvider)),
);
final technicianCommandsProvider =
    StateNotifierProvider<TechnicianCommands, AsyncValue<void>>(
  (ref) => TechnicianCommands(ref.watch(repositoryProvider)),
);
