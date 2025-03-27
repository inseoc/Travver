import 'package:flutter/material.dart';
import 'package:travver/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travver/screens/home_screen.dart';
import 'package:travver/constants/app_assets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<OnboardingItem> _pages = [
    OnboardingItem(
      title: '오사카 여행 계획 세우기',
      description: '편리한 계획 도구로 오사카 여행 일정을 효율적으로 구성해보세요.',
      icon: Icons.map_outlined,
    ),
    OnboardingItem(
      title: '스마트한 예산 관리로 효율적인 여행',
      description: '항목별 예산 설정과 지출 추적을 통해 오사카 여행 비용을 효율적으로 관리하세요.',
      icon: Icons.account_balance_wallet,
    ),
    OnboardingItem(
      title: '오사카 현지 정보로 완벽한 여행 경험',
      description: '최신 현지 정보와 추천 장소로 더욱 특별한 오사카 여행을 경험하세요.',
      icon: Icons.location_city,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 (페이지 인디케이터 및 스킵 버튼)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 페이지 인디케이터
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        width: index == _currentPage ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: index == _currentPage
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  
                  // 스킵 버튼 (마지막 페이지가 아닐 때만 표시)
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        '건너뛰기',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 온보딩 페이지 컨텐츠
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 일러스트레이션
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: index == 0 ? 
                          // 첫 번째 화면에서는 오사카 랜드마크 이미지 사용
                          ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(50),
                              child: Image.asset(
                                AppAssets.landmarkSilhouettePath,
                                color: AppColors.primary,
                              ),
                            ),
                          ) : 
                          // 나머지 화면에서는 아이콘 사용
                          Icon(
                            _pages[index].icon,
                            size: 100,
                            color: AppColors.primary,
                          ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 제목
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _pages[index].title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 설명
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _pages[index].description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 16,
                            color: AppColors.textGray,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            // 하단 버튼 영역
            Padding(
              padding: const EdgeInsets.all(24),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      children: [
                        // 시작하기 버튼
                        ElevatedButton(
                          onPressed: _navigateToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            '시작하기',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 로그인 버튼
                        OutlinedButton(
                          onPressed: () {
                            // 로그인 화면으로 이동
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            '로그인',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        '다음',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
} 