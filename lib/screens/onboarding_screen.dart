import 'package:flutter/material.dart';
import 'package:travver/constants/app_colors.dart';
// import 'package:google_fonts/google_fonts.dart'; // 테마 사용으로 불필요
import 'package:travver/screens/home_screen.dart';
import 'package:travver/constants/app_assets.dart';

// Onboarding 페이지 데이터 모델
class OnboardingItem {
  final String title;
  final String description;
  final IconData? icon; // 아이콘은 선택적
  final String? imagePath; // 이미지 경로 추가 (선택적)

  const OnboardingItem({
    required this.title,
    required this.description,
    this.icon,
    this.imagePath,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Onboarding 데이터 (이미지 경로 예시 추가)
  final List<OnboardingItem> _pages = [
    const OnboardingItem(
      title: '나만의 오사카 여행 설계하기', // 문구 수정
      description: 'AI 컨설턴트와 함께 당신의 취향에 꼭 맞는 오사카 여행 계획을 만들어보세요.', // 문구 수정
      imagePath: AppAssets.landmarkSilhouettePath, // 첫 페이지는 이미지 사용
    ),
    const OnboardingItem(
      title: '스마트한 예산 관리 도우미',
      description: '정해진 예산 안에서 최대 만족을! 항목별 지출 계획과 최적화 제안을 받아보세요.',
      icon: Icons.account_balance_wallet_outlined, // 아이콘 변경
    ),
    const OnboardingItem(
      title: '실시간 오사카 여행 정보',
      description: '놓치면 아쉬울 현지 이벤트, 맛집, 쇼핑 정보까지! Travver가 알려드릴게요.',
      icon: Icons.local_offer_outlined, // 아이콘 변경
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    // 마지막 페이지로 바로 이동하는 대신 홈 화면으로 이동하도록 변경 (선택적)
    _navigateToHome(); 
    // 또는 기존 로직 유지
    // _pageController.animateToPage(
    //   _pages.length - 1,
    //   duration: const Duration(milliseconds: 400),
    //   curve: Curves.easeInOut,
    // );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      // 페이드 애니메이션 전환 효과 추가 (선택적)
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      // MaterialPageRoute(builder: (context) => const HomeScreen()), // 기존 방식
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // backgroundColor: Colors.white, // 테마의 scaffoldBackgroundColor 사용
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 (페이지 인디케이터 및 스킵 버튼)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 페이지 인디케이터
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: index == _currentPage
                              ? colorScheme.primary // 테마 색상 사용
                              : colorScheme.primary.withOpacity(0.3), // 비활성 색상 조정
                        ),
                      ),
                    ),
                  ),
                  
                  // 스킵 버튼
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textGray, // 테마 색상 사용
                      ),
                      child: Text(
                        '건너뛰기',
                        style: textTheme.labelMedium, // 테마 텍스트 스타일 사용
                      ),
                    )
                  else 
                    const SizedBox(height: 48), // 마지막 페이지에서 스킵 버튼 공간 확보
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
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0), // 좌우 패딩 추가
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 일러스트레이션 또는 아이콘
                        Container(
                          width: MediaQuery.of(context).size.width * 0.6, // 화면 너비 비례
                          height: MediaQuery.of(context).size.width * 0.6,
                          margin: const EdgeInsets.only(bottom: 48), // 하단 마진 증가
                          decoration: BoxDecoration(
                            // color: colorScheme.primary.withOpacity(0.05), // 배경색은 선택적
                            shape: BoxShape.circle, // 원형 유지 또는 제거
                          ),
                          child: item.imagePath != null
                            ? Padding(
                                padding: const EdgeInsets.all(40), // 내부 패딩 조정
                                child: Image.asset(
                                  item.imagePath!,
                                  color: colorScheme.primary, // 테마 색상 적용
                                ),
                              )
                            : Icon(
                                item.icon,
                                size: 100,
                                color: colorScheme.primary,
                              ),
                        ),
                        
                        // 제목
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: textTheme.displaySmall?.copyWith( // 테마 스타일 적용
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 설명
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith( // 테마 스타일 적용
                            color: AppColors.textGray,
                            height: 1.5, // 줄 간격 조정
                          ),
                        ),
                        const SizedBox(height: 60), // 하단 여백 추가
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // 하단 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 시작하기 버튼 (테마 적용)
                        ElevatedButton(
                          onPressed: _navigateToHome,
                          child: const Text('Travver 시작하기'), // 버튼 텍스트 변경
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 로그인 버튼 (테마 적용)
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context); // 이전 화면(로그인)으로 돌아가기
                          },
                          child: const Text('이미 계정이 있어요'), // 버튼 텍스트 변경
                        ),
                      ],
                    )
                  // 다음 버튼 (테마 적용)
                  : ElevatedButton(
                      onPressed: _nextPage,
                      child: const Text('다음'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 