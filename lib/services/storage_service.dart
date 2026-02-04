import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/decorated_photo.dart';

/// 로컬 저장소 서비스
class StorageService {
  static const String _tripsKey = 'trips';
  static const String _photosKey = 'decorated_photos';

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

  // ── 꾸며진 사진 저장 ──

  /// 여행별 꾸며진 사진 조회
  Future<List<DecoratedPhoto>> getPhotosByTripId(String tripId) async {
    final allPhotos = await _getAllPhotos();
    return allPhotos.where((p) => p.tripId == tripId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 꾸며진 사진 저장
  Future<void> savePhoto(DecoratedPhoto photo) async {
    final photos = await _getAllPhotos();
    final existingIndex = photos.indexWhere((p) => p.id == photo.id);
    if (existingIndex != -1) {
      photos[existingIndex] = photo;
    } else {
      photos.insert(0, photo);
    }
    await _saveAllPhotos(photos);
  }

  /// 꾸며진 사진 삭제
  Future<void> deletePhoto(String photoId) async {
    final photos = await _getAllPhotos();
    photos.removeWhere((p) => p.id == photoId);
    await _saveAllPhotos(photos);
  }

  Future<List<DecoratedPhoto>> _getAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList(_photosKey) ?? [];
    return photosJson.map((json) {
      final Map<String, dynamic> data = jsonDecode(json);
      return DecoratedPhoto.fromJson(data);
    }).toList();
  }

  Future<void> _saveAllPhotos(List<DecoratedPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = photos.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_photosKey, photosJson);
  }
}
