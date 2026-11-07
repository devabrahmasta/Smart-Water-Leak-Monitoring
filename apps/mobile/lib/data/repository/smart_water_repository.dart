import '../models/models.dart';

/// Semua akses data aplikasi. Implementasi: [HttpSmartWaterRepository]
/// (backend asli) dan [MockSmartWaterRepository] (data contoh sesuai kontrak).
/// Layar tidak boleh tahu implementasi mana yang dipakai.
abstract interface class SmartWaterRepository {
  Future<Summary> getSummary();

  Future<List<Room>> getRooms();

  Future<RoomDetail> getRoom(int id);

  /// [roomId] null = semua kamar.
  Future<Usage> getUsage(UsagePeriod period, {int? roomId});

  /// [status] null = semua.
  Future<AlertPage> getAlerts({AlertStatus? status, int? limit, int? before});

  Future<Alert> getAlert(int id);

  Future<List<ValveCommand>> getRoomCommands(int roomId, {int limit = 10});

  /// Kirim perintah valve. Mengembalikan `command_id` (status PENDING).
  /// Melempar ApiException `deviceOffline` / `commandInProgress`.
  Future<int> sendValveCommand(int roomId, CommandAction action);

  Future<ValveCommand> getCommand(int id);

  Future<void> registerPushToken(String token);
}
