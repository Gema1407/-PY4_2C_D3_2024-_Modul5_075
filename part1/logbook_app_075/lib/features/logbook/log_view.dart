import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:logbook_app_075/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_075/features/logbook/log_controller.dart';
import 'package:logbook_app_075/features/logbook/models/log_model.dart';
import 'package:logbook_app_075/services/mongo_service.dart';
import 'package:logbook_app_075/helpers/log_helper.dart';
import 'package:logbook_app_075/services/access_control_service.dart';
import 'package:logbook_app_075/features/logbook/log_editor_page.dart';

class LogView extends StatefulWidget {
  final String username;
  final String role;
  const LogView({super.key, required this.username, required this.role});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isOffline = false; // Connection Guard state

  @override
  void initState() {
    super.initState();
    _controller = LogController(widget.username, widget.role);

    // Memberikan kesempatan UI merender widget awal sebelum proses berat dimulai
    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    try {
      await LogHelper.writeLog(
        "UI: Memulai inisialisasi database...",
        source: "log_view.dart",
      );

      // Mencoba koneksi ke MongoDB Atlas (Cloud)
      await LogHelper.writeLog(
        "UI: Menghubungi MongoService.connect()...",
        source: "log_view.dart",
      );

      // Mengaktifkan kembali koneksi dengan timeout 15 detik (lebih longgar untuk sinyal HP)
      await MongoService().connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          "Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist.",
        ),
      );

      await LogHelper.writeLog(
        "UI: Koneksi MongoService BERHASIL.",
        source: "log_view.dart",
      );

      // Mengambil data log (Offline-First: Hive dulu, lalu sync Cloud)
      await LogHelper.writeLog(
        "UI: Memanggil controller.loadLogs()...",
        source: "log_view.dart",
      );

      await _controller.loadLogs('team_A');

      await LogHelper.writeLog(
        "UI: Data berhasil dimuat ke Notifier.",
        source: "log_view.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "UI: Error - $e",
        source: "log_view.dart",
        level: 1,
      );
      // Tetap muat data dari cache Hive meskipun offline
      _controller.logsNotifier.value = Hive.box<LogModel>(
        'offline_logs',
      ).values.toList();
      if (mounted) {
        setState(() => _isOffline = true); // nyalakan offline mode
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Tidak dapat terhubung ke Cloud. Mode Offline aktif.",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // 2. INILAH FINALLY: Apapun yang terjadi (Sukses/Gagal/Data Kosong), loading harus mati
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Pull-to-Refresh: re-fetch dari Cloud dan reset offline state
  Future<void> _refreshData() async {
    setState(() => _isOffline = false);
    try {
      await MongoService().connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          "Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist.",
        ),
      );
      await _controller.loadLogs('team_A');
    } catch (e) {
      if (mounted) {
        setState(() => _isOffline = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Masih offline. Periksa koneksi internet Anda.",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // Navigasi ke Halaman Editor (menggantikan dialog lama)
  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          username: widget.username,
          role: widget.role,
        ),
      ),
    ).then((_) {
      // Refresh list setelah kembali dari editor
      _controller.loadLogs('team_A');
    });
  }

  Color _categoryBorderColor(String category) {
    switch (category) {
      case 'Pekerjaan':
        return const Color(0xFF4A90E2); // Elegant Blue
      case 'Pribadi':
        return const Color(0xFF50C878); // Elegant Green
      case 'Urgent':
        return const Color(0xFFE74C3C); // Elegant Red
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Pekerjaan':
        return Icons.work;
      case 'Pribadi':
        return Icons.person;
      case 'Urgent':
        return Icons.warning_amber_rounded;
      default:
        return Icons.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C7BFF);
    const bgDark = Color(0xFF0A0E1A);
    const cardColor = Color(0xFF151C2C);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1321), Color(0xFF151C2C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.book_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Halo, ${widget.username}! 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Logbook Cloud',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8892A4),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Sync status indicator
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isSynced,
            builder: (context, synced, _) {
              return Tooltip(
                message: synced
                    ? 'Tersinkron ke Cloud'
                    : 'Ada data yang belum tersinkron',
                child: Icon(
                  synced ? Icons.cloud_done : Icons.cloud_off,
                  color: synced
                      ? const Color(0xFF50C878)
                      : const Color(0xFFD97706),
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8892A4)),
            tooltip: 'Keluar',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      "Konfirmasi Logout",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      "Apakah Anda yakin ingin keluar?",
                      style: TextStyle(color: Color(0xFF8892A4)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Batal",
                          style: TextStyle(color: Color(0xFF8892A4)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Decorative background orbs ───────────────────────────────
          Positioned(
            top: 40,
            right: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C7BFF).withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5EEAD4).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB347).withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 30,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFC8181).withOpacity(0.07),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────────
          Column(
            children: [
              // ── Offline Mode Warning Banner ──────────────────────────────
              if (_isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFD97706), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '⚠️ Offline Mode — Data mungkin tidak terkini. Tarik ke bawah untuk mencoba ulang.',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _refreshData,
                        child: const Icon(
                          Icons.refresh,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Search Bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan judul...',
                    hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6C7BFF),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF4A5568),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1A2236),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF6C7BFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              // ── List Content ──────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF6C7BFF),
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Menghubungkan ke MongoDB Cloud...",
                              style: TextStyle(color: Color(0xFF4A5568)),
                            ),
                          ],
                        ),
                      )
                    : ValueListenableBuilder<List<LogModel>>(
                        valueListenable: _controller.logsNotifier,
                        builder: (context, currentLogs, child) {
                          // Data Privacy: tampilkan hanya milik sendiri atau yang isPublic
                          final visibleLogs = currentLogs.where((log) {
                            return log.authorId == widget.username ||
                                log.isPublic == true;
                          }).toList();

                          final filteredLogs = _searchQuery.isEmpty
                              ? visibleLogs
                              : visibleLogs
                                    .where(
                                      (log) => log.title.toLowerCase().contains(
                                        _searchQuery.toLowerCase(),
                                      ),
                                    )
                                    .toList();

                          if (filteredLogs.isEmpty) {
                            // ── Empty State dengan SVG ─────────────────
                            return RefreshIndicator(
                              onRefresh: _refreshData,
                              color: const Color(0xFF6C7BFF),
                              backgroundColor: const Color(0xFF151C2C),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/cloud_offline.svg',
                                          width: 130,
                                          height: 100,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'Belum ada catatan di Cloud.'
                                              : 'Catatan tidak ditemukan.',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF4A5568),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (_searchQuery.isEmpty) ...[
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Klik tombol  +  untuk menambahkan!',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          // ── Pull-to-Refresh wraps the list ────────────
                          return RefreshIndicator(
                            onRefresh: _refreshData,
                            color: const Color(0xFF6C7BFF),
                            backgroundColor: const Color(0xFF151C2C),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                final originalIndex = currentLogs.indexOf(log);
                                final borderColor = _categoryBorderColor(
                                  log.category,
                                );
                                final icon = _categoryIcon(log.category);
                                // Data Sovereignty: hanya pemilik yang bisa edit/hapus
                                final bool isOwner =
                                    log.authorId == widget.username;
                                final bool canEdit = isOwner;
                                final bool canDelete = isOwner;

                                // ── Timestamp formatting: timeago ──────
                                String formattedTime = '';
                                try {
                                  final dt = DateTime.parse(log.date).toLocal();
                                  formattedTime = timeago.format(
                                    dt,
                                    locale: 'id',
                                  );
                                } catch (_) {
                                  formattedTime = log.date;
                                }

                                return Dismissible(
                                  key: ValueKey('${log.title}_${log.date}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (direction) async {
                                    if (!canDelete) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Anda tidak memiliki izin untuk menghapus catatan ini.',
                                          ),
                                        ),
                                      );
                                      return false;
                                    }
                                    return await showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF151C2C,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: const Text(
                                            "Konfirmasi Hapus",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          content: const Text(
                                            "Apakah Anda yakin ingin menghapus catatan ini?",
                                            style: TextStyle(
                                              color: Color(0xFF8892A4),
                                            ),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text(
                                                "Batal",
                                                style: TextStyle(
                                                  color: Color(0xFF8892A4),
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text("Hapus"),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  onDismissed: (_) =>
                                      _controller.removeLog(originalIndex),
                                  background: const SizedBox.shrink(),
                                  secondaryBackground: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.delete_sweep,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Hapus',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: Card(
                                    color: const Color(0xFF151C2C),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: borderColor.withOpacity(0.28),
                                        width: 1,
                                      ),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 5,
                                      horizontal: 4,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor: borderColor
                                            .withOpacity(0.15),
                                        child: Icon(
                                          icon,
                                          color: borderColor,
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(
                                        log.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            log.description,
                                            style: const TextStyle(
                                              color: Color(0xFF8892A4),
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              // Category badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: borderColor
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: borderColor
                                                        .withOpacity(0.4),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  log.category,
                                                  style: TextStyle(
                                                    color: borderColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Timestamp badge
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time_rounded,
                                                      size: 11,
                                                      color: Color(0xFF4A5568),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                      child: Text(
                                                        formattedTime,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF4A5568,
                                                          ),
                                                          fontSize: 11,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (canEdit)
                                            GestureDetector(
                                              onTap: () => _goToEditor(
                                                log: log,
                                                index: originalIndex,
                                              ),
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF6C7BFF,
                                                  ).withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Color(0xFF6C7BFF),
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                          if (canEdit && canDelete)
                                            const SizedBox(width: 6),
                                          if (canDelete)
                                            GestureDetector(
                                              onTap: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF151C2C,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      title: const Text(
                                                        "Konfirmasi Hapus",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      content: const Text(
                                                        "Apakah Anda yakin ingin menghapus catatan ini?",
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF8892A4,
                                                          ),
                                                        ),
                                                      ),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(false),
                                                          child: const Text(
                                                            "Batal",
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF8892A4,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(true),
                                                          child: const Text(
                                                            "Hapus",
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                                if (confirm == true) {
                                                  _controller.removeLog(
                                                    originalIndex,
                                                  );
                                                }
                                              },
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.redAccent,
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ), // end Column
        ],
      ), // end Stack
      floatingActionButton: FloatingActionButton(
        onPressed: _goToEditor,
        backgroundColor: const Color(0xFF6C7BFF),
        foregroundColor: Colors.white,
        elevation: 8,
        child: const Icon(Icons.add),
      ),
    );
  }
}
