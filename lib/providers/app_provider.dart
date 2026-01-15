import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 상태 관리 Provider
class AppProvider extends ChangeNotifier {
  bool _isFirstLaunch = true;
  bool _isLoading = false;
  String? _userName;

  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoading => _isLoading;
  String? get userName => _userName;
  String get displayName => _userName ?? '여행자';

  AppProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    _userName = prefs.getString('userName');
    notifyListeners();
  }

  /// 온보딩 완료 처리
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    _isFirstLaunch = false;
    notifyListeners();
  }

  /// 사용자 이름 설정
  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    _userName = name;
    notifyListeners();
  }

  /// 로딩 상태 설정
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 앱 데이터 초기화 (디버그용)
  Future<void> resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isFirstLaunch = true;
    _userName = null;
    notifyListeners();
  }
}
