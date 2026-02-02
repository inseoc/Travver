import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/daily_plan.dart';
import '../services/storage_service.dart';

/// 여행 상태 관리 Provider
class TripProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<Trip> _trips = [];
  Trip? _currentTrip;
  bool _isLoading = false;
  String? _error;

  List<Trip> get trips => _trips;
  Trip? get currentTrip => _currentTrip;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 상태별 여행 목록
  List<Trip> get upcomingTrips =>
      _trips.where((t) => t.status == TripStatus.upcoming).toList();

  List<Trip> get ongoingTrips =>
      _trips.where((t) => t.status == TripStatus.ongoing).toList();

  List<Trip> get completedTrips =>
      _trips.where((t) => t.status == TripStatus.completed).toList();

  /// 추억 남기기 가능한 여행 (시작일 <= 오늘)
  List<Trip> get memoryEligibleTrips {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _trips.where((t) {
      final start = DateTime(t.period.start.year, t.period.start.month, t.period.start.day);
      return !start.isAfter(today);
    }).toList();
  }

  TripProvider() {
    loadTrips();
  }

  /// 여행 목록 로드
  Future<void> loadTrips() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _trips = await _storageService.getAllTrips();
      _updateTripStatuses();
    } catch (e) {
      _error = '여행 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 여행 상태 자동 업데이트 (날짜 기반)
  void _updateTripStatuses() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var trip in _trips) {
      if (trip.period.end.isBefore(today)) {
        trip.status = TripStatus.completed;
      } else if (trip.period.start.isAfter(today)) {
        trip.status = TripStatus.upcoming;
      } else {
        trip.status = TripStatus.ongoing;
      }
    }
  }

  /// 새 여행 추가
  Future<void> addTrip(Trip trip) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.saveTrip(trip);
      _trips.insert(0, trip);
      _currentTrip = trip;
    } catch (e) {
      _error = '여행을 저장하는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 여행 업데이트
  Future<void> updateTrip(Trip trip) async {
    try {
      await _storageService.saveTrip(trip);
      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index != -1) {
        _trips[index] = trip;
      }
      if (_currentTrip?.id == trip.id) {
        _currentTrip = trip;
      }
      notifyListeners();
    } catch (e) {
      _error = '여행을 업데이트하는데 실패했습니다: $e';
      notifyListeners();
    }
  }

  /// 여행 삭제
  Future<void> deleteTrip(String tripId) async {
    try {
      await _storageService.deleteTrip(tripId);
      _trips.removeWhere((t) => t.id == tripId);
      if (_currentTrip?.id == tripId) {
        _currentTrip = null;
      }
      notifyListeners();
    } catch (e) {
      _error = '여행을 삭제하는데 실패했습니다: $e';
      notifyListeners();
    }
  }

  /// 특정 여행 선택
  void selectTrip(String tripId) {
    _currentTrip = _trips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => _trips.first,
    );
    notifyListeners();
  }

  /// 특정 여행 가져오기
  Trip? getTripById(String tripId) {
    try {
      return _trips.firstWhere((t) => t.id == tripId);
    } catch (e) {
      return null;
    }
  }

  /// 현재 여행 초기화
  void clearCurrentTrip() {
    _currentTrip = null;
    notifyListeners();
  }

  /// 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
