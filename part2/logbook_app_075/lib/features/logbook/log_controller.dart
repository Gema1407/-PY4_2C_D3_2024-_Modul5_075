import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:logbook_app_075/services/mongo_service.dart';
import 'models/log_model.dart';
import 'package:logbook_app_075/helpers/log_helper.dart';
import 'package:logbook_app_075/services/access_control_service.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);

  /// true = semua data sudah di cloud, false = ada data pending/offline
  final ValueNotifier<bool> isSynced = ValueNotifier(true);

  final String _username;
  final String _userRole;
  String _teamId = 'team_A';

  Box<LogModel> get _myBox => Hive.box<LogModel>('offline_logs');
  Box<String> get _pendingBox => Hive.box<String>('pending_sync');

  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  LogController(String username, String role)
    : _username = username,
      _userRole = role {
    // Listener koneksi — auto-sync saat internet aktif kembali
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _pendingBox.isNotEmpty) {
        _syncPending();
      }
    });
  }

  void dispose() {
    _connectivitySub.cancel();
    logsNotifier.dispose();
    isSynced.dispose();
  }

  /// Push log pending ke Atlas saat koneksi pulih (anti-duplikasi)
  Future<void> _syncPending() async {
    if (_pendingBox.isEmpty) return;

    final pendingIds = _pendingBox.values.toSet();
    final pendingLogs = _myBox.values
        .where((l) => l.id != null && pendingIds.contains(l.id))
        .toList();

    for (final log in pendingLogs) {
      try {
        await MongoService().insertLog(log);
        // Hapus dari pending queue setelah berhasil
        final key = _pendingBox.keys.firstWhere(
          (k) => _pendingBox.get(k) == log.id,
        );
        await _pendingBox.delete(key);
        await LogHelper.writeLog(
          "SYNC: Pending '${log.title}' berhasil dikirim ke Atlas",
          source: "log_controller.dart",
          level: 2,
        );
      } catch (e) {
        await LogHelper.writeLog(
          "SYNC: Gagal sync '${log.title}' - $e",
          source: "log_controller.dart",
          level: 1,
        );
      }
    }

    isSynced.value = _pendingBox.isEmpty;

    // Refresh UI dengan data cloud terbaru setelah semua pending terkirim
    if (_pendingBox.isEmpty) {
      await loadLogs(_teamId);
    }
  }

  /// 1. LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String teamId) async {
    _teamId = teamId;

    // Langkah 1: Ambil dari Hive dulu (instan)
    logsNotifier.value = _myBox.values.toList();

    // Langkah 2: Sync dari Cloud (background)
    try {
      final cloudData = await MongoService().getLogs(teamId);
      final pendingIds = _pendingBox.values.toSet();

      // Pertahankan log pending agar tidak hilang saat clear
      final pendingLogs = _myBox.values
          .where((l) => l.id != null && pendingIds.contains(l.id))
          .toList();

      // Merge: cloud + pending lokal (anti-duplikasi by id)
      final cloudIds = cloudData.map((l) => l.id).toSet();
      final uniquePending = pendingLogs
          .where((l) => !cloudIds.contains(l.id))
          .toList();
      final merged = [...cloudData, ...uniquePending];

      await _myBox.clear();
      await _myBox.addAll(merged);

      logsNotifier.value = merged;
      isSynced.value = pendingIds.isEmpty;

      await LogHelper.writeLog(
        "SYNC: Data berhasil diperbarui dari Atlas",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      isSynced.value = _pendingBox.isEmpty ? true : false;
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  /// Alias agar backward-compatible
  Future<void> loadFromDisk({String teamId = 'team_A'}) => loadLogs(teamId);

  /// 2. ADD DATA (Instant Local + Background Cloud)
  Future<void> addLog(
    String title,
    String desc, {
    String category = 'Umum',
    String teamId = 'team_A',
    bool isPublic = false,
  }) async {
    final newLog = LogModel(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now().toIso8601String(),
      authorId: _username,
      teamId: teamId,
      category: category,
      isPublic: isPublic,
    );

    // ACTION 1: Simpan ke Hive (instan)
    await _myBox.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];

    // ACTION 2: Kirim ke Atlas (background)
    try {
      await MongoService().insertLog(newLog);
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      // Masuk ke pending queue untuk dicoba saat online nanti
      await _pendingBox.add(newLog.id!);
      isSynced.value = false;
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  Future<void> updateLog(
    int index,
    String title,
    String desc, {
    String category = 'Umum',
    bool isPublic = false,
  }) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    // Data Sovereignty: hanya pemilik yang boleh edit
    if (targetLog.authorId != _username) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized update attempt by $_username",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    final updatedLog = LogModel(
      id: targetLog.id,
      title: title,
      description: desc,
      date: DateTime.now().toIso8601String(),
      authorId: targetLog.authorId,
      teamId: targetLog.teamId,
      category: category,
      isPublic: isPublic,
    );

    await MongoService().updateLog(updatedLog);
    await loadFromDisk(teamId: updatedLog.teamId);
  }

  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final target = currentLogs[index];

    // Data Sovereignty: hanya pemilik yang boleh hapus
    if (target.authorId != _username) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized delete attempt by $_username",
        source: "log_controller.dart",
        level: 1,
      );
      return;
    }

    final logId = target.id;
    if (logId != null) {
      await MongoService().deleteLog(logId);
      await loadFromDisk(teamId: target.teamId);
    }
  }
}
