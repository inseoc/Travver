import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// 위치 좌표 모델
class Location extends Equatable {
  final double lat;
  final double lng;

  const Location({
    required this.lat,
    required this.lng,
  });

  /// flutter_map에서 사용하는 LatLng로 변환
  LatLng toLatLng() => LatLng(lat, lng);

  /// 두 지점 간의 거리 계산 (미터)
  double distanceTo(Location other) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      toLatLng(),
      other.toLatLng(),
    );
  }

  /// 거리를 읽기 쉬운 형식으로 변환
  String distanceStringTo(Location other) {
    final meters = distanceTo(other);
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }

  factory Location.fromLatLng(LatLng latLng) {
    return Location(lat: latLng.latitude, lng: latLng.longitude);
  }

  @override
  List<Object?> get props => [lat, lng];

  @override
  String toString() => 'Location($lat, $lng)';
}
