import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';

/// 로컬 저장소 서비스
class StorageService {
  static const String _tripsKey = 'trips';

  /// 모든 여행 조회
  Future<List<Trip>> getAllTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getStringList(_tripsKey) ?? [];

    return tripsJson.map((json) {
      final Map<String, dynamic> data = jsonDecode(json);
      return Trip.fromJson(data);
    }).toList();
  }

  /// 여행 저장
  Future<void> saveTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = await getAllTrips();

    // 기존 여행 업데이트 또는 새 여행 추가
    final existingIndex = trips.indexWhere((t) => t.id == trip.id);
    if (existingIndex != -1) {
      trips[existingIndex] = trip;
    } else {
      trips.insert(0, trip);
    }

    final tripsJson = trips.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tripsKey, tripsJson);
  }

  /// 여행 삭제
  Future<void> deleteTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = await getAllTrips();

    trips.removeWhere((t) => t.id == tripId);

    final tripsJson = trips.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tripsKey, tripsJson);
  }

  /// 특정 여행 조회
  Future<Trip?> getTripById(String tripId) async {
    final trips = await getAllTrips();
    try {
      return trips.firstWhere((t) => t.id == tripId);
    } catch (e) {
      return null;
    }
  }

  /// 모든 여행 삭제
  Future<void> clearAllTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripsKey);
  }
}
