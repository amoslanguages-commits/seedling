import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../core/supabase_config.dart';
import 'auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================ CLOUD BACKUP SERVICE ================

class CloudBackupService {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal();
  
  Future<void> createBackup() async {
    await backupDatabase();
  }
  
  Future<List<BackupInfo>> listBackups() async {
    if (!AuthService().isAuthenticated) return [];
    
    try {
      final userId = AuthService().userId;
      final List<FileObject> objects = await SupabaseConfig.client.storage
          .from('backups')
          .list(path: userId);
          
      return objects.map((obj) => BackupInfo(
        id: obj.name,
        createdAt: DateTime.parse(obj.createdAt ?? DateTime.now().toIso8601String()),
        size: obj.metadata?['size'] ?? 0,
      )).toList();
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  Future<void> backupDatabase() async {
    if (!AuthService().isAuthenticated) return;
    
    try {
      final userId = AuthService().userId;
      final dbPath = path.join(await getDatabasesPath(), 'seedling.db');
      final file = File(dbPath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await SupabaseConfig.client.storage
            .from('backups')
            .uploadBinary(
              '$userId/backup_$timestamp.db',
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        
        debugPrint('Cloud backup successful');
      }
    } catch (e) {
      debugPrint('Cloud backup error: $e');
      rethrow;
    }
  }
  
  Future<void> restoreFromBackup([String? backupId]) async {
    if (!AuthService().isAuthenticated) return;
    
    try {
      final userId = AuthService().userId;
      final dbPath = path.join(await getDatabasesPath(), 'seedling.db');
      
      final String fileName = backupId ?? 'seedling_backup.db';
      final bytes = await SupabaseConfig.client.storage
          .from('backups')
          .download('$userId/$fileName');
      
      final file = File(dbPath);
      await file.writeAsBytes(bytes);
      
      debugPrint('Restore from backup successful');
    } catch (e) {
      debugPrint('Restore error: $e');
      rethrow;
    }
  }
}

class BackupInfo {
  final String id;
  final DateTime createdAt;
  final int size;
  
  BackupInfo({
    required this.id,
    required this.createdAt,
    required this.size,
  });
}
