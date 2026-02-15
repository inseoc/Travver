import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

/// 앱 전역 상태 관리 Provider (SQLite 기반)
class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

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
    final firstLaunch = await _db.getConfig('is_first_launch');
    _isFirstLaunch = firstLaunch == null || firstLaunch == 'true';
    _userName = await _db.getConfig('user_name');
    notifyListeners();
  }

  /// 온보딩 완료 처리
  Future<void> completeOnboarding() async {
    await _db.setConfig('is_first_launch', 'false');
    _isFirstLaunch = false;
    notifyListeners();
  }

  /// 사용자 이름 설정
  Future<void> setUserName(String name) async {
    await _db.setConfig('user_name', name);
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
    await _db.setConfig('is_first_launch', 'true');
    await _db.setConfig('user_name', '');
    _isFirstLaunch = true;
    _userName = null;
    notifyListeners();
  }
}
