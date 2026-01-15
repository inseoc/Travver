import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'app/routes.dart';
import 'providers/trip_provider.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 세로 모드 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TravverApp());
}

class TravverApp extends StatelessWidget {
  const TravverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: MaterialApp.router(
        title: 'Travver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          // 텍스트 스케일 고정 (접근성 설정 무시)
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child ?? const SizedBox(),
          );
        },
      ),
    );
  }
}
