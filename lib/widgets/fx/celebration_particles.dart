import 'dart:typed_data';
import 'dart:ui';

/// Reusable buffers for the cosmetic's round grains: one atlas draw, rather
/// than hundreds of individual circles for every dressed creature.
class CelebrationParticles {
  static const _capacity = 640;
  static const _cell = 64.0;
  final _transforms = Float32List(_capacity * 4);
  final _rects = Float32List(_capacity * 4);
  final _colors = Int32List(_capacity);
  var _count = 0;
  static Image? _dot;
  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  void clear() => _count = 0;
  void add(Offset at, double radius, Color color, double alpha) {
    if (_count >= _capacity || alpha <= 0 || radius <= 0) return;
    final i = _count * 4;
    final scale = radius * 6 / _cell;
    _transforms[i] = scale;
    _transforms[i + 1] = 0;
    _transforms[i + 2] = at.dx - radius * 3;
    _transforms[i + 3] = at.dy - radius * 3;
    _rects[i] = 0;
    _rects[i + 1] = 0;
    _rects[i + 2] = _cell;
    _rects[i + 3] = _cell;
    _colors[_count++] = color
        .withValues(alpha: alpha.clamp(0.0, 1.0))
        .toARGB32();
  }

  void draw(Canvas canvas) {
    if (_count == 0) return;
    canvas.drawRawAtlas(
      _dot ??= _buildDot(),
      Float32List.sublistView(_transforms, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      _paint,
    );
  }

  static Image _buildDot() {
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawCircle(
      const Offset(32, 32),
      32,
      Paint()
        ..shader = Gradient.radial(
          const Offset(32, 32),
          32,
          const [
            Color(0xFFFFFFFF),
            Color(0xD9FFFFFF),
            Color(0x4DFFFFFF),
            Color(0x14FFFFFF),
            Color(0x00FFFFFF),
          ],
          const [0, 0.13, 0.3, 0.6, 1],
        ),
    );
    final picture = rec.endRecording();
    final image = picture.toImageSync(64, 64);
    picture.dispose();
    return image;
  }
}
