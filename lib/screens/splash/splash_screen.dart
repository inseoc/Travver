import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../providers/app_provider.dart';

/// 스플래시 화면
/// - 앱 로딩 및 브랜드 노출
/// - 2초 후 자동으로 온보딩/홈 화면으로 전환
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToNext();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final appProvider = context.read<AppProvider>();

    if (appProvider.isFirstLaunch) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // 로고 및 앱 이름
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  // 로고 아이콘
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppShadows.elevated,
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing24),

                  // 앱 이름
                  Text(
                    'Travver',
                    style: AppTypography.headline1.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing8),

                  // 태그라인
                  Text(
                    'AI 여행 플래너',
                    style: AppTypography.body1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // 로딩 인디케이터
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accent.withOpacity(0.8),
                  ),
                  minHeight: 3,
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spacing48),
          ],
        ),
      ),
    );
  }
}
