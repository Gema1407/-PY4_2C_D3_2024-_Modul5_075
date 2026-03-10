import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_075/features/logbook/models/log_model.dart';
import 'package:logbook_app_075/features/logbook/log_controller.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel? log;
  final int? index;
  final LogController controller;
  final String username;
  final String role;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.username,
    required this.role,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String _selectedCategory = 'Umum';
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(
      text: widget.log?.description ?? '',
    );
    _selectedCategory = widget.log?.category ?? 'Umum';
    _isPublic = widget.log?.isPublic ?? false;

    // Listener agar Pratinjau terupdate otomatis
    _descController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tidak boleh kosong.')),
      );
      return;
    }

    if (widget.log == null) {
      // Tambah Baru
      await widget.controller.addLog(
        _titleController.text,
        _descController.text,
        category: _selectedCategory,
        isPublic: _isPublic,
      );
    } else {
      // Update
      await widget.controller.updateLog(
        widget.index!,
        _titleController.text,
        _descController.text,
        category: _selectedCategory,
        isPublic: _isPublic,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.log == null
                ? 'Catatan berhasil ditambahkan!'
                : 'Catatan berhasil diperbarui!',
          ),
          backgroundColor: const Color(0xFF50C878),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.log == null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF151C2C),
          foregroundColor: Colors.white,
          title: Text(
            isNew ? 'Catatan Baru' : 'Edit Catatan',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF6C7BFF),
            unselectedLabelColor: Color(0xFF8892A4),
            indicatorColor: Color(0xFF6C7BFF),
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Editor'),
              Tab(icon: Icon(Icons.preview), text: 'Pratinjau'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Simpan',
              onPressed: _save,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Editor ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Judul',
                      labelStyle: const TextStyle(color: Color(0xFF8892A4)),
                      filled: true,
                      fillColor: const Color(0xFF1A2236),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      labelStyle: const TextStyle(color: Color(0xFF8892A4)),
                      filled: true,
                      fillColor: const Color(0xFF1A2236),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    dropdownColor: const Color(0xFF1A2236),
                    style: const TextStyle(color: Colors.white),
                    items: ['Pekerjaan', 'Pribadi', 'Urgent', 'Umum']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Toggle Visibility: Private / Public
                  GestureDetector(
                    onTap: () => setState(() => _isPublic = !_isPublic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isPublic
                            ? const Color(0xFF50C878).withOpacity(0.12)
                            : const Color(0xFF6C7BFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isPublic
                              ? const Color(0xFF50C878).withOpacity(0.4)
                              : const Color(0xFF4A5568).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPublic ? Icons.public : Icons.lock_outline,
                            color: _isPublic
                                ? const Color(0xFF50C878)
                                : const Color(0xFF8892A4),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPublic
                                ? 'Publik — Terlihat oleh tim'
                                : 'Privat — Hanya saya yang lihat',
                            style: TextStyle(
                              color: _isPublic
                                  ? const Color(0xFF50C878)
                                  : const Color(0xFF8892A4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2236),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _descController,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Tulis laporan dengan format Markdown...\n\n# Judul\n**tebal**, *miring*, `kode`\n- item list',
                          hintStyle: TextStyle(
                            color: Color(0xFF4A5568),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab 2: Markdown Preview ──────────────────────────────
            Container(
              color: const Color(0xFF0A0E1A),
              child: Markdown(
                data: _descController.text.isEmpty
                    ? '*Belum ada konten untuk ditampilkan...*'
                    : _descController.text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white70, fontSize: 14),
                  h1: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    color: Color(0xFF6C7BFF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  strong: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  em: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontStyle: FontStyle.italic,
                  ),
                  code: const TextStyle(
                    color: Color(0xFFFFB347),
                    backgroundColor: Color(0xFF1A2236),
                    fontFamily: 'monospace',
                  ),
                  listBullet: const TextStyle(color: Color(0xFF6C7BFF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
