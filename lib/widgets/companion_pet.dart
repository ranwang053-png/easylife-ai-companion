import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CompanionPet extends StatelessWidget {
  const CompanionPet({super.key, this.size = 116});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '桌宠一团',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PetPainter()),
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    canvas.scale(scale);

    final shadow = Paint()
      ..color = const Color(0x18000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(const Rect.fromLTWH(22, 91, 78, 13), shadow);

    final body = Paint()..color = const Color(0xFFFFFCFA);
    final outline = Paint()
      ..color = const Color(0xFFD8C8CD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(23, 87)
      ..cubicTo(12, 76, 19, 58, 32, 54)
      ..cubicTo(31, 37, 43, 28, 58, 34)
      ..cubicTo(73, 25, 91, 35, 89, 53)
      ..cubicTo(104, 59, 106, 80, 94, 89)
      ..cubicTo(78, 102, 39, 101, 23, 87)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawPath(path, outline);

    final purple = Paint()..color = const Color(0xFFA889D9);
    canvas.drawCircle(const Offset(44, 36), 7, purple);
    canvas.drawCircle(const Offset(57, 29), 8, purple);
    canvas.drawCircle(const Offset(72, 35), 7, purple);

    final eye = Paint()..color = AppColors.ink;
    canvas.drawCircle(const Offset(48, 66), 3.3, eye);
    canvas.drawCircle(const Offset(76, 66), 3.3, eye);
    canvas.drawCircle(const Offset(49, 65), 0.9, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(77, 65), 0.9, Paint()..color = Colors.white);

    final blush = Paint()..color = const Color(0xFFF5BEC8);
    canvas.drawOval(const Rect.fromLTWH(35, 72, 12, 6), blush);
    canvas.drawOval(const Rect.fromLTWH(78, 72, 12, 6), blush);

    final mouth = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(const Rect.fromLTWH(56, 67, 7, 7), 0.1, 2.7, false, mouth);
    canvas.drawArc(const Rect.fromLTWH(63, 67, 7, 7), 0.35, 2.7, false, mouth);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
