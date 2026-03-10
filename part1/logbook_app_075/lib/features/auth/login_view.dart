import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logbook_app_075/features/auth/login_controller.dart';
import 'package:logbook_app_075/features/logbook/log_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  int _failedAttempts = 0;
  bool _isLocked = false;
  int _countdownSeconds = 10;
  Timer? _lockoutTimer;
  bool _isPasswordVisible = false;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _startLockoutTimer() {
    setState(() {
      _isLocked = true;
      _countdownSeconds = 10;
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isLocked = false;
          _failedAttempts = 0;
        });
      }
    });
  }

  void _handleLogin() {
    if (_isLocked) return;

    final user = _userController.text.trim();
    final pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          "Username dan Password tidak boleh kosong!",
          Colors.orange,
        ),
      );
      return;
    }

    final isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      setState(() => _failedAttempts = 0);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) =>
              LogView(username: user, role: _controller.getRole(user)),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      setState(() => _failedAttempts++);
      if (_failedAttempts >= 3) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar(
            "Terlalu banyak percobaan! Tunggu 10 detik.",
            Colors.red,
          ),
        );
        _startLockoutTimer();
      } else {
        final remaining = 3 - _failedAttempts;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar("Login Gagal! Sisa percobaan: $remaining", Colors.red),
        );
      }
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _userController.dispose();
    _passController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C7BFF);
    const bgDark = Color(0xFF0A0E1A);
    const cardColor = Color(0xFF151C2C);
    const fieldColor = Color(0xFF1A2236);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Ambient glow top-left
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A6C7BFF),
              ),
            ),
          ),
          // Ambient glow bottom-right
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0F5EEAD4),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo / Icon ──────────────────────────────────
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withOpacity(0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Greeting ─────────────────────────────────────
                    const Text(
                      'Selamat Datang!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masuk ke LogBook Anda untuk melanjutkan',
                      style: TextStyle(fontSize: 14, color: Color(0xFF8892A4)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // ── Form Card ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF2D3748),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Username field
                          TextField(
                            controller: _userController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Masukkan username',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: accent,
                              ),
                              filled: true,
                              fillColor: fieldColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: accent,
                                  width: 1.5,
                                ),
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF8892A4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextField(
                            controller: _passController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Masukkan password',
                              prefixIcon: const Icon(
                                Icons.key_rounded,
                                color: accent,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF4A5568),
                                ),
                                onPressed: () => setState(
                                  () =>
                                      _isPasswordVisible = !_isPasswordVisible,
                                ),
                              ),
                              filled: true,
                              fillColor: fieldColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: accent,
                                  width: 1.5,
                                ),
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFF8892A4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Failed attempts warning
                          if (_failedAttempts > 0 && !_isLocked)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sisa percobaan: ${3 - _failedAttempts}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Locked countdown
                          if (_isLocked)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Akun dikunci — coba lagi dalam $_countdownSeconds dtk',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: _isLocked
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF6C7BFF),
                                          Color(0xFF5560E0),
                                        ],
                                      ),
                                color: _isLocked
                                    ? const Color(0xFF2D3748)
                                    : null,
                                boxShadow: _isLocked
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF6C7BFF,
                                          ).withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLocked ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white54,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isLocked
                                          ? Icons.lock_clock
                                          : Icons.login_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isLocked
                                          ? 'Tunggu $_countdownSeconds detik...'
                                          : 'Masuk',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Footer
                    const Text(
                      'LogBook App • 075',
                      style: TextStyle(color: Color(0xFF2D3748), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
