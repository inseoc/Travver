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
      duration: const Duration(seconds: 2),
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    
    // 3초 후 로그인 화면으로 이동
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.splashGradientStart,
              AppColors.splashGradientEnd,
            ],
          ),
          image: DecorationImage(
            image: const AssetImage(AppAssets.splashBackgroundPath),
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
        ),
        child: Stack(
          children: [
            // 하단에 오사카 랜드마크 실루엣
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
                      width: 200,
                      height: 200,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // 앱 이름
                    const Text(
                      'Travver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // 태그라인
                    const Text(
                      '오사카 여행의 모든 것',
                      style: TextStyle(
                        color: AppColors.textLightGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 하단 로딩 인디케이터
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
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