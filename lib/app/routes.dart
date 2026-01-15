import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/plan_input/plan_input_screen.dart';
import '../screens/plan_result/plan_result_screen.dart';
import '../screens/ai_consultant/ai_consultant_screen.dart';
import '../screens/my_trips/my_trips_screen.dart';
import '../screens/memories/memories_screen.dart';
import '../screens/memories/photo_decorator_screen.dart';
import '../screens/memories/video_creator_screen.dart';

/// 앱 라우트 경로 상수
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String planInput = '/plan/input';
  static const String planResult = '/plan/result';
  static const String aiConsultant = '/consultant';
  static const String myTrips = '/trips';
  static const String tripDetail = '/trips/:tripId';
  static const String memories = '/memories';
  static const String photoDecorator = '/memories/photo';
  static const String videoCreator = '/memories/video';
}

/// GoRouter 설정
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // 스플래시 화면
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // 온보딩 화면
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 홈 화면
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // 새 여행 계획 입력
      GoRoute(
        path: AppRoutes.planInput,
        name: 'planInput',
        builder: (context, state) => const PlanInputScreen(),
      ),

      // 여행 계획 결과
      GoRoute(
        path: AppRoutes.planResult,
        name: 'planResult',
        builder: (context, state) {
          final tripId = state.extra as String?;
          return PlanResultScreen(tripId: tripId);
        },
      ),

      // AI 컨설턴트
      GoRoute(
        path: AppRoutes.aiConsultant,
        name: 'aiConsultant',
        builder: (context, state) => const AiConsultantScreen(),
      ),

      // 내 여행 목록
      GoRoute(
        path: AppRoutes.myTrips,
        name: 'myTrips',
        builder: (context, state) => const MyTripsScreen(),
      ),

      // 여행 상세
      GoRoute(
        path: AppRoutes.tripDetail,
        name: 'tripDetail',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return PlanResultScreen(tripId: tripId);
        },
      ),

      // 추억 남기기
      GoRoute(
        path: AppRoutes.memories,
        name: 'memories',
        builder: (context, state) => const MemoriesScreen(),
      ),

      // 사진 꾸미기
      GoRoute(
        path: AppRoutes.photoDecorator,
        name: 'photoDecorator',
        builder: (context, state) {
          final tripId = state.extra as String?;
          return PhotoDecoratorScreen(tripId: tripId);
        },
      ),

      // 나만의 영상
      GoRoute(
        path: AppRoutes.videoCreator,
        name: 'videoCreator',
        builder: (context, state) {
          final tripId = state.extra as String?;
          return VideoCreatorScreen(tripId: tripId);
        },
      ),
    ],

    // 에러 페이지
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '페이지를 찾을 수 없습니다',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('홈으로 돌아가기'),
            ),
          ],
        ),
      ),
    ),
  );
}
