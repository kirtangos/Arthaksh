import 'package:flutter/material.dart';

class NoiseDecoration extends Decoration {
  final Color color;
  final double opacity;

  const NoiseDecoration({
    required this.color,
    this.opacity = 0.03,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _NoisePainter(color, opacity);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    return Path()..addRect(rect);
  }

  @override
  int get hashCode => color.hashCode ^ opacity.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoiseDecoration &&
        other.color == color &&
        other.opacity == opacity;
  }
}

class _NoisePainter extends BoxPainter {
  final Color color;
  final double opacity;

  _NoisePainter(this.color, this.opacity);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;

    // Create a subtle noise pattern using canvas operations
    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Add subtle noise dots
    final Random random = Random(42); // Fixed seed for consistent pattern
    for (int i = 0; i < 200; i++) {
      final double x = rect.left + random.nextDouble() * rect.width;
      final double y = rect.top + random.nextDouble() * rect.height;
      final double radius = random.nextDouble() * 0.5 + 0.1;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
}

class Random {
  int _state;

  Random(int seed) : _state = seed;

  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 2147483647.0;
  }
}
