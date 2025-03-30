import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // 테마 사용으로 불필요
import 'package:travver/constants/app_colors.dart'; // 부분적으로 필요할 수 있음
import 'package:travver/constants/app_assets.dart';
import 'ai_consultant_screen.dart'; // AI 컨설턴트 화면 import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final String _userName = "Travver"; // 예시 사용자 이름 (실제로는 인증 상태에서 가져와야 함)

  // 각 탭에 해당하는 화면 위젯 리스트 (실제 구현 필요)
  final List<Widget> _screens = [
    const _HomeTabContent(), // 홈 탭 컨텐츠 위젯
    const Center(child: Text('여행 계획 Screen')), // 여행 계획 탭
    const Center(child: Text('예산 관리 Screen')), // 예산 관리 탭
    const Center(child: Text('내 정보 Screen')), // 내 정보 탭
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        // 테마의 appBarTheme이 적용됨 (backgroundColor, elevation, foregroundColor 등)
        leadingWidth: 80, // 로고/앱이름 공간 확보
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            children: [
              Image.asset(
                AppAssets.logoPath,
                height: 24, // 로고 높이 조정
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.travel_explore, color: colorScheme.primary, size: 24);
                },
              ),
              // const SizedBox(width: 8), // 로고만 표시할 경우 주석 처리
              // Text('Travver', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                // 프로필 화면으로 이동
                setState(() { _currentIndex = 3; }); // 예시: 내 정보 탭으로 이동
              },
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.surfaceVariant, // 테마 색상 활용
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack( // 탭 간 상태 유지를 위해 IndexedStack 사용
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        // backgroundColor: theme.colorScheme.surface, // Material 3에서는 기본값 사용
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.textGray,
        selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold), // 선택된 라벨 스타일
        unselectedLabelStyle: theme.textTheme.labelSmall, // 선택되지 않은 라벨 스타일
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
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
}

// --- 홈 탭 컨텐츠 위젯 ---
class _HomeTabContent extends StatelessWidget {
  const _HomeTabContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    const String userName = "Travver"; // 예시 사용자 이름

    return ListView( // SingleChildScrollView 대신 ListView 사용 (더 많은 컨텐츠에 적합)
      padding: const EdgeInsets.only(bottom: 40), // 하단 여백
      children: [
        // --- 사용자 인사말 섹션 ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요, $userName님 👋',
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '오늘 오사카 여행을 위한 영감을 받아보세요!',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textGray),
              ),
            ],
          ),
        ),

        // --- 핵심 기능 카드 ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildFeatureCard(
                context: context,
                title: 'AI 여행 컨설턴트',
                description: 'AI와 대화하며 나만의 오사카 루트 완성!',
                backgroundColor: theme.colorScheme.primaryContainer,
                icon: Icons.assistant_outlined,
                buttonText: '시작하기',
                onTap: () {
                  // AI 컨설턴트 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AiConsultantScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                context: context,
                title: '스마트 예산 플래너',
                description: '여행 경비, 쉽고 똑똑하게 관리해요.',
                backgroundColor: theme.colorScheme.secondaryContainer,
                icon: Icons.savings_outlined,
                buttonText: '예산 관리 시작',
                onTap: () {
                  // TODO: 예산 관리 화면으로 이동하는 로직 구현
                  print('예산 관리 시작 버튼 클릭됨');
                   // 예시: 예산 탭으로 이동
                   // DefaultTabController.of(context)?.animateTo(2);
                   // 또는 Navigator 사용
                   // Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetScreen()));

                  // 현재 구조에서는 BottomNavigationBar를 직접 제어하기 어려움
                  // 상태 관리 솔루션(Provider, Riverpod 등)을 사용하거나
                  // HomeScreen의 _currentIndex를 변경하는 콜백을 전달해야 함.
                  // 임시로 콘솔 출력만 유지
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // --- 오사카 추천 명소 섹션 (임시 주석 처리 - AppAssets 정의 필요) ---
        /*
        _buildSectionTitle(context, '놓치면 후회할 오사카 명소 ✨'),
        SizedBox(
          height: 230, // 카드 높이 조정
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8), // 패딩 조정 (오른쪽 카드 마진 고려)
            itemCount: 5, // 예시 아이템 개수
            itemBuilder: (context, index) {
              // 예시 데이터 (실제로는 모델에서 가져와야 함)
              final places = [
                const _PlaceCardData(title: '오사카 성', description: '도시의 상징, 역사 속으로', imagePath: AppAssets.dummyPlace1),
                const _PlaceCardData(title: '도톤보리', description: '활기찬 네온사인과 먹거리', imagePath: AppAssets.dummyPlace2),
                const _PlaceCardData(title: '유니버설 스튜디오', description: '짜릿한 어트랙션!', imagePath: AppAssets.dummyPlace3),
                const _PlaceCardData(title: '신세카이 & 츠텐카쿠', description: '레트로 감성 탐방', imagePath: AppAssets.dummyPlace4),
                const _PlaceCardData(title: '우메다 공중정원', description: '환상적인 야경 스팟', imagePath: AppAssets.dummyPlace5),
              ];
              return _PlaceCard(data: places[index]);
            },
          ),
        ),
        */

        const SizedBox(height: 32),

        // --- 추천 여행 테마 섹션 ---
        _buildSectionTitle(context, '이런 테마 여행은 어때요?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildThemeTile(context, '🍜 식도락 미식 투어', Icons.ramen_dining_outlined, Colors.orange.shade100),
              _buildThemeTile(context, '🛍️ 쇼핑 성지 완전 정복', Icons.shopping_bag_outlined, Colors.blue.shade100),
              _buildThemeTile(context, '🏯 역사 & 문화 탐방', Icons.museum_outlined, Colors.green.shade100),
              _buildThemeTile(context, '🌃 로맨틱 야경 데이트', Icons.nightlife, Colors.purple.shade100),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper Methods for _HomeTabContent --- 

  // 섹션 제목
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // 핵심 기능 카드
  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String description,
    required Color backgroundColor,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // 배경색에 따른 onColor 계산 (밝기 기준)
    final Brightness brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    final Color onColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    final Color onColorMuted = onColor.withOpacity(0.7);

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: onColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: onColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: textTheme.bodyMedium?.copyWith(color: onColorMuted),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onTap, // 전달받은 onTap 콜백 사용
                style: ElevatedButton.styleFrom(
                  foregroundColor: backgroundColor, // 버튼 텍스트/아이콘 색 (배경색과 대비되도록)
                  backgroundColor: onColor, // 버튼 배경색
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                child: Text(buttonText), // 변경된 버튼 텍스트 사용
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 추천 테마 타일
  Widget _buildThemeTile(BuildContext context, String title, IconData icon, Color tileColor) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor, width: 0.5)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20, // 크기 조정
          backgroundColor: tileColor, 
          child: Icon(icon, color: theme.colorScheme.primary, size: 20)
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textGray),
        onTap: () { /* 테마 상세 화면 이동 */ },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

// --- 추천 장소 카드 데이터 모델 ---
class _PlaceCardData {
  final String title;
  final String description;
  final String imagePath;

  const _PlaceCardData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// --- 추천 장소 카드 위젯 ---
class _PlaceCard extends StatelessWidget {
  final _PlaceCardData data;

  const _PlaceCard({required this.data, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SizedBox( // 카드 크기 지정을 위해 SizedBox 사용
      width: 170, // 카드 너비 조정
      child: Card(
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8), // 카드 간격
        clipBehavior: Clip.antiAlias,
        // CardTheme의 elevation, shape 적용됨
        child: InkWell(
          onTap: () { /* 장소 상세 화면 이동 */ },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                data.imagePath,
                height: 130, // 이미지 높이 조정
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 130,
                    color: theme.colorScheme.surfaceVariant, // 이미지 없을 때 배경색
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurfaceVariant, 
                        size: 32
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.description,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textGray),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 