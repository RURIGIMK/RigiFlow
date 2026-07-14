import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class FlowRibbonBackground extends StatefulWidget {
  final Widget child;
  const FlowRibbonBackground({super.key, required this.child});

  @override
  State<FlowRibbonBackground> createState() => _FlowRibbonBackgroundState();
}

class _FlowRibbonBackgroundState extends State<FlowRibbonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _RibbonPainter(progress: _controller.value),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final double progress;
  _RibbonPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.flow.withOpacity(0.18),
          AppColors.surface.withOpacity(0.0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    // Using a more natural wave calculation
    final waveOffset = sin(progress * 2 * pi) * 40;
    path.moveTo(0, size.height * 0.15);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.05 + waveOffset,
      size.width,
      size.height * 0.25,
    );
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.progress != progress;
}