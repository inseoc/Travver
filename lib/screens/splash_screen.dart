import 'dart:async';
import 'package:flutter/material.dart';
import 'package:travver/constants/app_colors.dart';
import 'package:travver/constants/app_assets.dart';
import 'package:travver/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // AppColors.splashGradientStart, // 기존 색상 주석 처리
              // AppColors.splashGradientEnd,
              Color(0xFFFFF0F5), // 연한 벚꽃색 (Lavender Blush)
              Color(0xFFFFC0CB), // 조금 더 진한 벚꽃색 (Pink)
            ],
          ),
        ),
        child: Stack(
          children: [
            // 하단에 오사카 랜드마크 실루엣 (제거)
            /*
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  AppAssets.landmarkSilhouettePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            */
            
            // 메인 콘텐츠
            Center(
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고
                    Image.asset(
                      AppAssets.logoPath,
                      width: 180,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 앱 이름
                    Text(
                      'Travver',
                      style: textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 태그라인
                    Text(
                      '오사카 여행의 모든 것',
                      style: textTheme.bodyLarge?.copyWith(
                        // color: AppColors.textLightGray, // 기존 색상 주석 처리
                        color: AppColors.textDark, // 어두운 텍스트 색상으로 변경
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 하단 로딩 인디케이터
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 