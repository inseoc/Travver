import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travver/constants/app_colors.dart';
import 'package:travver/constants/app_assets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Travver',
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            AppAssets.logoPath,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
                size: 24,
              );
            },
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 사용자 인사말 섹션
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                image: DecorationImage(
                  image: const AssetImage('assets/images/splash_background.png'),
                  fit: BoxFit.cover,
                  opacity: 0.1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, 홍길동님',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오사카 여행을 함께 계획해볼까요?',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 예산 관리 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFeatureCard(
                title: '예산 관리 어드바이저',
                description: '효율적인 여행 예산 관리를 도와드립니다',
                color: AppColors.secondary,
                icon: Icons.account_balance_wallet_outlined,
                buttonText: '예산 설정하기',
                onTap: () {
                  // 예산 관리 화면으로 이동
                },
              ),
            ),

            const SizedBox(height: 16),

            // 여행 계획 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFeatureCard(
                title: '여행 계획 세우기',
                description: '오사카 여행 일정을 효율적으로 계획하세요',
                color: AppColors.primary,
                icon: Icons.map_outlined,
                buttonText: '계획하기',
                onTap: () {
                  // 여행 계획 화면으로 이동
                },
              ),
            ),

            const SizedBox(height: 24),

            // 추가 컨텐츠 - 오사카 추천 명소
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오사카 추천 명소',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildPlaceCard('오사카성', '일본 역사의 상징적인 성곽'),
                        _buildPlaceCard('도톤보리', '오사카의 활기찬 먹거리 거리'),
                        _buildPlaceCard('유니버설 스튜디오', '온 가족이 즐기는 테마파크'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 오사카 랜드마크 이미지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오사카 랜드마크',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      AppAssets.landmarkSilhouettePath,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: const Color(0xFF9CA3AF),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '여행 계획',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: '예산 관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          color: AppColors.textLightGray,
                        ),
                      ),
                    ],
                  ),
                ),
                // 버튼
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(String name, String description) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 (데모용 컬러 컨테이너)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      AppAssets.splashBackgroundPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    name == '오사카성' ? Icons.castle_outlined :
                    name == '도톤보리' ? Icons.restaurant_outlined :
                    Icons.attractions_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 