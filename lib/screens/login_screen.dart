import 'package:flutter/material.dart';
import 'package:travver/constants/app_colors.dart';
import 'package:travver/constants/app_assets.dart';
import 'package:travver/screens/onboarding_screen.dart';
import 'package:travver/screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      // 로그인 처리 후 홈 화면으로 직접 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _navigateToOnboarding() {
    // 온보딩 화면으로 이동
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              
              // 로고 및 앱 이름
              Center(
                child: Column(
                  children: [
                    // 로고
                    Image.asset(
                      AppAssets.logoPath,
                      width: 120,
                      height: 120,
                      // 이미지가 없는 경우 대체 위젯
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined, 
                              size: 60,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 앱 이름
                    Text(
                      'Travver',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 태그라인
                    Text(
                      '오사카 여행의 모든 것',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // 로그인 폼
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이메일 필드
                    Text(
                      '이메일',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: '이메일 주소를 입력하세요',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '이메일을 입력해주세요';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return '올바른 이메일 형식이 아닙니다';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 비밀번호 필드
                    Text(
                      '비밀번호',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: '비밀번호를 입력하세요',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible 
                              ? Icons.visibility_outlined 
                              : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요';
                        }
                        if (value.length < 6) {
                          return '비밀번호는 6자 이상이어야 합니다';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 로그인 유지하기 & 비밀번호 찾기
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 로그인 유지하기
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '로그인 유지하기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 14,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        
                        // 비밀번호 찾기
                        TextButton(
                          onPressed: () {
                            // 비밀번호 찾기 화면으로 이동 (미구현)
                          },
                          child: Text(
                            '비밀번호 찾기',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 로그인 버튼
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 소셜 로그인 안내
                    Center(
                      child: Text(
                        '또는 소셜 계정으로 로그인',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 소셜 로그인 버튼들
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 카카오 로그인
                        _buildSocialLoginButton(
                          icon: Icons.chat_bubble,
                          color: const Color(0xFFFEE500),
                          onPressed: () {},
                        ),
                        
                        const SizedBox(width: 24),
                        
                        // 네이버 로그인
                        _buildSocialLoginButton(
                          icon: Icons.tag,
                          color: const Color(0xFF03C75A),
                          onPressed: () {},
                        ),
                        
                        const SizedBox(width: 24),
                        
                        // 구글 로그인
                        _buildSocialLoginButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFF4285F4),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 회원가입 안내 및 버튼
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요?',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              color: AppColors.textGray,
                            ),
                          ),
                          TextButton(
                            onPressed: _navigateToOnboarding,
                            child: Text(
                              '회원가입',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSocialLoginButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 0,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
          ),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
} 