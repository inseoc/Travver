import 'package:flutter/material.dart';
import 'package:travver/constants/app_colors.dart';
import 'package:travver/constants/app_assets.dart';
import 'package:travver/screens/onboarding_screen.dart';
import 'package:travver/screens/home_screen.dart';

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
    if (_formKey.currentState?.validate() ?? false) {
      // 로그인 처리 로직 (API 호출 등)
      
      // 로그인 성공 시 홈 화면으로 이동 (애니메이션 적용)
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _navigateToOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }
  
  // 소셜 로그인 함수 (예시)
  void _loginWithGoogle() { /* Google 로그인 로직 */ }
  void _loginWithApple() { /* Apple 로그인 로직 */ }
  void _loginWithKakao() { /* Kakao 로그인 로직 */ }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // 로고 및 앱 이름
              Center(
                child: Column(
                  children: [
                    // 로고
                    Image.asset(
                      AppAssets.logoPath,
                      width: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.travel_explore,
                            size: 50,
                            color: colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 앱 이름
                    Text(
                      'Travver',
                      style: textTheme.displayMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 태그라인
                    Text(
                      '오사카 여행의 모든 것, 트래버와 함께',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 로그인 폼
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: '이메일 주소',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textGray),
                      ),
                      style: textTheme.bodyMedium,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '이메일을 입력해주세요.';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return '올바른 이메일 형식이 아닙니다.';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: '비밀번호',
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.textGray),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible 
                              ? Icons.visibility_outlined 
                              : Icons.visibility_off_outlined,
                            color: AppColors.textGray,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      style: textTheme.bodyMedium,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요.';
                        }
                        if (value.length < 6) {
                          return '비밀번호는 6자 이상이어야 합니다.';
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
                                activeColor: colorScheme.primary,
                                checkColor: colorScheme.onPrimary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: Text(
                                '로그인 상태 유지',
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textGray),
                              ),
                            ),
                          ],
                        ),
                        
                        // 비밀번호 찾기
                        TextButton(
                          onPressed: () {
                            // TODO: 비밀번호 찾기 화면 로직 구현
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('비밀번호 찾기 기능은 준비중입니다.')),
                            );
                          },
                          child: Text(
                            '비밀번호를 잊으셨나요?',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 로그인 버튼
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('로그인'),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 소셜 로그인 구분선
                    Row(
                      children: [
                        const Expanded(child: Divider(height: 1, thickness: 0.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'SNS 계정으로 로그인',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textGray),
                          ),
                        ),
                        const Expanded(child: Divider(height: 1, thickness: 0.5)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 소셜 로그인 버튼 영역 (임시 주석 처리 - AppAssets 정의 필요)
                    /*
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialLoginButton(AppAssets.googleLogoPath, _loginWithGoogle),
                        const SizedBox(width: 20),
                        _buildSocialLoginButton(AppAssets.appleLogoPath, _loginWithApple),
                        const SizedBox(width: 20),
                        _buildSocialLoginButton(AppAssets.kakaoLogoPath, _loginWithKakao),
                      ],
                    ),
                    */
                    
                    const SizedBox(height: 40),
                    
                    // 회원가입 안내
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '아직 계정이 없으신가요? ',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textGray),
                        ),
                        TextButton(
                          onPressed: _navigateToOnboarding,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '회원가입',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton(String assetPath, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textLightGray, width: 0.5),
        ),
        child: Image.asset(
          assetPath,
          height: 24,
          width: 24,
        ),
      ),
    );
  }
} 