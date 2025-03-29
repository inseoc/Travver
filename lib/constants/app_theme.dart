import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // 주석 처리 또는 삭제
import 'app_colors.dart';

class AppTheme {
  static const String _fontFamily = 'Pretendard'; // 폰트 패밀리 이름 정의

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily, // 앱 전체 기본 폰트 설정
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
        error: AppColors.accent,
        onPrimary: AppColors.textLight, // Primary 색상 위의 텍스트 색
        onSecondary: AppColors.textDark, // Secondary 색상 위의 텍스트 색
        onBackground: AppColors.textDark, // Background 색상 위의 텍스트 색
        onError: AppColors.textLight,    // Error 색상 위의 텍스트 색
        surface: Colors.white,           // 카드, 시트 등의 표면 색상
        onSurface: AppColors.textDark,   // 표면 색상 위의 텍스트 색
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        displaySmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
        headlineSmall: TextStyle( // 추가: 작은 제목 스타일
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle( // 추가: AppBar 제목 등에 사용
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: AppColors.textDark
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textDark,
        ),
        bodySmall: TextStyle( // 추가: 더 작은 본문/설명
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textGray,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textLight, // 버튼 등 내부 텍스트
        ),
        labelMedium: TextStyle( // 추가: 중간 크기 라벨
          fontSize: 14, 
          fontWeight: FontWeight.w500, 
          color: AppColors.textDark
        ),
        labelSmall: TextStyle( // 추가: 작은 라벨/캡션
          fontSize: 11, 
          fontWeight: FontWeight.normal, 
          color: AppColors.textGray
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          minimumSize: const Size(double.infinity, 52), // 높이 약간 줄임
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // 각진 느낌으로 변경
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily, // 폰트 패밀리 명시
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 2, // 약간의 그림자 추가
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.5), // 테두리 두께 조정
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily, // 폰트 패밀리 명시
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background, // 배경색과 동일하게 설정하거나 흰색 유지
        hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14), // 힌트 텍스트 스타일
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLightGray), // 연한 회색 테두리
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // 패딩 조정
      ),
      // 추가적인 테마 설정 (AppBar, Card 등)
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background, // AppBar 배경색
        foregroundColor: AppColors.textDark, // AppBar 아이콘/텍스트 색상
        elevation: 0, // 그림자 제거
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        iconTheme: IconThemeData(color: AppColors.textDark), // 아이콘 테마
      ),
      cardTheme: CardTheme(
        elevation: 1, // 카드 그림자 약간
        color: Colors.white, // 카드 배경색
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // 부드러운 모서리
          side: BorderSide(color: AppColors.textLightGray, width: 0.5), // 얇은 테두리 (선택적)
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // 카드 간격
      ),
    );
  }
} 