import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Decorative product silhouette, never a connection or battery indicator.
class RingDeviceIllustration extends StatelessWidget {
  const RingDeviceIllustration({this.size = 72, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RingPainter()),
    ),
  );
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.38);
    final outer = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .67,
      height: size.height * .82,
    );
    final inner = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .42,
      height: size.height * .62,
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(outer),
      Path()..addOval(inner),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF82939B),
            Color(0xFF243B45),
            Color(0xFF4B626A),
            Color(0xFFB8C9CC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(outer),
    );
    canvas.drawOval(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = SaydianColors.outline.withValues(alpha: .6),
    );
    canvas.drawArc(
      outer.deflate(2),
      3.7,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .65),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}
