import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 커스텀 장소 마커
/// - 압정(Pin) 형태
/// - 방문 순서 번호 표시
class PlaceMarker extends StatelessWidget {
  final int order;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const PlaceMarker({
    super.key,
    required this.order,
    required this.color,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.3 : 1.0,
        duration: AppTheme.animationDuration,
        curve: AppTheme.animationCurve,
        child: AnimatedContainer(
          duration: AppTheme.animationDuration,
          curve: AppTheme.animationCurve,
          decoration: BoxDecoration(
            boxShadow: isSelected ? AppShadows.elevated : AppShadows.card,
          ),
          child: CustomPaint(
            size: const Size(40, 48),
            painter: _MarkerPainter(
              color: color,
              isSelected: isSelected,
            ),
            child: SizedBox(
              width: 40,
              height: 48,
              child: Align(
                alignment: const Alignment(0, -0.3),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$order',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  _MarkerPainter({
    required this.color,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 압정 형태의 마커 그리기
    final path = Path();

    // 원형 상단
    final centerX = size.width / 2;
    final topY = 4.0;
    final radius = size.width / 2 - 4;

    path.addOval(Rect.fromCircle(
      center: Offset(centerX, topY + radius),
      radius: radius,
    ));

    // 꼬리 부분 (삼각형)
    path.moveTo(centerX - radius * 0.5, topY + radius + radius * 0.5);
    path.lineTo(centerX, size.height - 4);
    path.lineTo(centerX + radius * 0.5, topY + radius + radius * 0.5);
    path.close();

    // 그림자
    if (isSelected) {
      canvas.drawShadow(path, Colors.black, 4, false);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}
