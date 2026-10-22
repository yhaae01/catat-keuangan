import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import '../../theme_provider.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  final Duration duration;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  late AnimationController _dotsController;

  bool _hasNavigated = false;
  String _loadingMessage = 'Menyiapkan database & akun...';

  @override
  void initState() {
    super.initState();

    // Hapus native splash jika sebelumnya di-preserve
    FlutterNativeSplash.remove();

    // 1. Animasi entrance Logo & Konten
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutBack,
      ),
    );

    // 2. Animasi denyut halus pada ambient glow di belakang logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.10).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 3. Animasi looping 3 titik (loading dots)
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 4. Animasi progress loading utama
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    _progressController.addListener(() {
      final value = _progressController.value;
      String nextMessage;
      if (value < 0.30) {
        nextMessage = 'Menyiapkan database & akun...';
      } else if (value < 0.65) {
        nextMessage = 'Memuat transaksi & ringkasan saldo...';
      } else if (value < 0.92) {
        nextMessage = 'Menyiapkan antarmuka...';
      } else {
        nextMessage = 'Selamat datang!';
      }

      if (_loadingMessage != nextMessage && mounted) {
        setState(() {
          _loadingMessage = nextMessage;
        });
      }
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToDashboard();
      }
    });

    // Jalankan animasi
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _dotsController.repeat();
    _progressController.forward();
  }

  void _navigateToDashboard() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _pulseController.stop();
    _dotsController.stop();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = themeProvider.primaryColor;
    const backgroundColor = Color(0xFF0F172A); // Sesuai warna native splash

    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToDashboard,
        child: Stack(
          children: [
            // Ambient Glow Dekoratif
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Tombol Lewati (Skip)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton.icon(
                    onPressed: _navigateToDashboard,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                    ),
                    icon: const Text(
                      'Lewati',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    label: const Icon(Icons.arrow_forward_ios, size: 11),
                  ),
                ),
              ),
            ),

            // Konten Tengah
            Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // App Logo dengan Efek Glow Denyut
                              _buildAppLogo(primaryColor),

                              const SizedBox(height: 28),

                              // Judul Aplikasi
                              const Text(
                                'Catat Keuangan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Tagline Aplikasi
                              Text(
                                'Kelola Finansial Lebih Bijak & Teratur',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                              ),

                              const SizedBox(height: 44),

                              // Komponen Animasi Loading Bar & Status
                              _buildLoadingSection(primaryColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Footer / Versi
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22.0),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: primaryColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Catat Keuangan • Versi 1.0.0',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo(Color primaryColor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final pulse = _pulseAnimation.value;
        return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B),
                const Color(0xFF0F172A),
              ],
            ),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35 * pulse),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.30 * pulse),
                blurRadius: 32 * pulse,
                spreadRadius: 2 * pulse,
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/app_icon_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.account_balance_wallet_rounded,
                size: 52,
                color: primaryColor,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingSection(Color primaryColor) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final progress = _progressAnimation.value;
        final percentage = (progress * 100).toInt();

        return Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar Track & Glow
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.02, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            const Color(0xFF10B981), // Emerald bright
                            const Color(0xFF38BDF8), // Cyan highlight
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pesan Status & Persentase
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _loadingMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildAnimatedDots(primaryColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: primaryColor.withValues(alpha: 0.95),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDots(Color primaryColor) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        final val = _dotsController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.25;
            final itemValue = ((val - delay) % 1.0);
            final opacity = (itemValue < 0.5 ? itemValue * 2 : (1.0 - itemValue) * 2)
                .clamp(0.2, 1.0);

            return Container(
              margin: const EdgeInsets.only(left: 2),
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
