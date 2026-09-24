import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database_service.dart';
import 'database/finance_repository.dart';
import 'security/security_service.dart';
import 'notifications/notification_service.dart';
import 'utils/backup_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Cache in-memory instance for web session so state persists across page changes
final _webInMemoryRepo = FinanceRepository.inMemory();

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  if (kIsWeb) {
    return _webInMemoryRepo;
  }
  final dbService = ref.watch(databaseServiceProvider);
  return FinanceRepository(dbService.isar);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  if (kIsWeb) {
    return BackupService(null as dynamic);
  }
  final dbService = ref.watch(databaseServiceProvider);
  return BackupService(dbService.isar);
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
