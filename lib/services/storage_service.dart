import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/decorated_photo.dart';
import 'database_service.dart';

/// 로컬 저장소 서비스 (SQLite 기반)
class StorageService {
  final DatabaseService _db = DatabaseService();

  // SharedPreferences 키 (마이그레이션 용)
  static const String _tripsKey = 'trips';
  static const String _photosKey = 'decorated_photos';

  /// 초기화 및 마이그레이션 수행
  Future<void> initialize() async {
    // DB 인스턴스 생성 (테이블 자동 생성)
    await _db.database;

    // SharedPreferences → SQLite 마이그레이션
    if (!await _db.isMigrated) {
      await _migrateFromSharedPreferences();
      await _db.markMigrated();
    }
  }

  /// SharedPreferences 데이터를 SQLite로 마이그레이션
  Future<void> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // trips 마이그레이션
    final tripsJson = prefs.getStringList(_tripsKey) ?? [];
    for (final json in tripsJson) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final trip = Trip.fromJson(data);
        await _db.saveTrip(trip);
      } catch (e) {
        // 마이그레이션 실패한 개별 항목은 건너뜀
        print('Trip migration failed: $e');
      }
    }

    // decorated_photos 마이그레이션
    final photosJson = prefs.getStringList(_photosKey) ?? [];
    for (final json in photosJson) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final photo = DecoratedPhoto.fromJson(data);
        await _db.savePhoto(photo);
      } catch (e) {
        print('Photo migration failed: $e');
      }
    }

    // isFirstLaunch, userName 마이그레이션
    final isFirstLaunch = prefs.getBool('isFirstLaunch');
    if (isFirstLaunch != null) {
      await _db.setConfig('is_first_launch', isFirstLaunch.toString());
    }
    final userName = prefs.getString('userName');
    if (userName != null) {
      await _db.setConfig('user_name', userName);
    }
  }

  // ── 여행 CRUD ──

  /// 모든 여행 조회
  Future<List<Trip>> getAllTrips() async {
    return await _db.getAllTrips();
  }

  /// 여행 저장
  Future<void> saveTrip(Trip trip) async {
    await _db.saveTrip(trip);
  }

  /// 여행 삭제
  Future<void> deleteTrip(String tripId) async {
    await _db.deleteTrip(tripId);
  }

  /// 특정 여행 조회
  Future<Trip?> getTripById(String tripId) async {
    return await _db.getTripById(tripId);
  }

  /// 모든 여행 삭제
  Future<void> clearAllTrips() async {
    await _db.clearAllTrips();
  }

  // ── 꾸며진 사진 CRUD ──

  /// 여행별 꾸며진 사진 조회
  Future<List<DecoratedPhoto>> getPhotosByTripId(String tripId) async {
    return await _db.getPhotosByTripId(tripId);
  }

  /// 꾸며진 사진 저장
  Future<void> savePhoto(DecoratedPhoto photo) async {
    await _db.savePhoto(photo);
  }

  /// 여행별 꾸며진 사진 개수 조회
  Future<int> getPhotoCountByTripId(String tripId) async {
    return await _db.getPhotoCountByTripId(tripId);
  }

  /// 모든 여행의 사진 개수를 Map으로 반환 {tripId: count}
  Future<Map<String, int>> getAllPhotoCountsByTrip() async {
    return await _db.getAllPhotoCountsByTrip();
  }

  /// 꾸며진 사진 이름 수정
  Future<void> updatePhotoDisplayName(String photoId, String displayName) async {
    await _db.updatePhotoDisplayName(photoId, displayName);
  }

  /// 꾸며진 사진 삭제
  Future<void> deletePhoto(String photoId) async {
    await _db.deletePhoto(photoId);
  }
}
