import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/background/starfield_background.dart';
import 'package:flutter/material.dart';

enum CreatureBgKind { color, checker, space }

class CreatureBgOption {
  final String id;
  final String label;
  final CreatureBgKind kind;
  final Color color;

  const CreatureBgOption.color({
    required this.id,
    required this.label,
    required this.color,
  }) : kind = CreatureBgKind.color;

  const CreatureBgOption.checker({required this.id, required this.label})
    : kind = CreatureBgKind.checker,
      color = const Color(0xFF202020);

  const CreatureBgOption.space({required this.id, required this.label})
    : kind = CreatureBgKind.space,
      color = const Color(0xFF050810);
}

const CreatureBgOption defaultCreatureBg = CreatureBgOption.space(
  id: 'space',
  label: 'Space',
);

const List<CreatureBgOption> creatureBgOptions = [
  defaultCreatureBg,
  CreatureBgOption.color(
    id: 'black',
    label: 'Black',
    color: Color(0xFF000000),
  ),
  CreatureBgOption.color(
    id: 'charcoal',
    label: 'Charcoal',
    color: Color(0xFF1A1A1A),
  ),
  CreatureBgOption.color(id: 'grey', label: 'Grey', color: Color(0xFF6B6B6B)),
  CreatureBgOption.color(id: 'white', label: 'White', color: Color(0xFFF2F2F2)),
  CreatureBgOption.color(id: 'ocean', label: 'Ocean', color: Color(0xFF0B3B5C)),
  CreatureBgOption.color(id: 'ember', label: 'Ember', color: Color(0xFF4A1E1E)),
  CreatureBgOption.color(
    id: 'forest',
    label: 'Forest',
    color: Color(0xFF1F3A1F),
  ),
  CreatureBgOption.checker(id: 'checker', label: 'Transparent'),
];

CreatureBgOption creatureBgById(String? id) {
  if (id == null) return defaultCreatureBg;
  for (final option in creatureBgOptions) {
    if (option.id == id) return option;
  }
  return defaultCreatureBg;
}

String _speciesKey(String baseId) => 'creature_bg:species:$baseId';
String _instanceKey(String instanceId) => 'creature_bg:instance:$instanceId';

/// Loads the saved bg for this creature. Instance preference wins over species.
/// Returns null if nothing has been saved (caller chooses default).
Future<CreatureBgOption?> loadCreatureBg(
  AlchemonsDatabase db, {
  required String baseId,
  String? instanceId,
}) async {
  if (instanceId != null) {
    final v = await db.settingsDao.getSetting(_instanceKey(instanceId));
    if (v != null && v.isNotEmpty) return creatureBgById(v);
  }
  final v = await db.settingsDao.getSetting(_speciesKey(baseId));
  if (v != null && v.isNotEmpty) return creatureBgById(v);
  return null;
}

Future<void> saveCreatureBgForSpecies(
  AlchemonsDatabase db, {
  required String baseId,
  required CreatureBgOption option,
}) {
  return db.settingsDao.setSetting(_speciesKey(baseId), option.id);
}

Future<void> saveCreatureBgForInstance(
  AlchemonsDatabase db, {
  required String instanceId,
  required CreatureBgOption option,
}) {
  return db.settingsDao.setSetting(_instanceKey(instanceId), option.id);
}

/// Renders the bg full-bleed. Cheap; safe to use under sprite hero or full-screen.
class CreatureBgLayer extends StatelessWidget {
  final CreatureBgOption option;
  final int spaceStarCount;
  final Color? spaceNebula;

  const CreatureBgLayer({
    super.key,
    required this.option,
    this.spaceStarCount = 160,
    this.spaceNebula = const Color(0xFF4A2E8E),
  });

  @override
  Widget build(BuildContext context) {
    switch (option.kind) {
      case CreatureBgKind.space:
        return StarfieldBackground(
          baseColor: const Color(0xFF050810),
          nebulaColor: spaceNebula,
          starCount: spaceStarCount,
        );
      case CreatureBgKind.checker:
        return RepaintBoundary(child: CustomPaint(painter: _CheckerPainter()));
      case CreatureBgKind.color:
        return ColoredBox(color: option.color);
    }
  }
}

class _CheckerPainter extends CustomPainter {
  static const double _cell = 14;
  static final Paint _a = Paint()..color = const Color(0xFF2A2A2A);
  static final Paint _b = Paint()..color = const Color(0xFF1A1A1A);

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * _cell, r * _cell, _cell, _cell),
          (r + c).isEven ? _a : _b,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}

/// Tiny round swatch used in pickers.
class CreatureBgSwatch extends StatelessWidget {
  final CreatureBgOption option;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const CreatureBgSwatch({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: selected ? 2.2 : 1.2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: ClipOval(child: _inner()),
      ),
    );
  }

  Widget _inner() {
    switch (option.kind) {
      case CreatureBgKind.space:
        return const _SpaceSwatchInner();
      case CreatureBgKind.checker:
        return CustomPaint(painter: _CheckerPainter());
      case CreatureBgKind.color:
        return ColoredBox(color: option.color);
    }
  }
}

class _SpaceSwatchInner extends StatelessWidget {
  const _SpaceSwatchInner();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050810)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF4A2E8E).withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
        CustomPaint(painter: _StaticStarsPainter()),
      ],
    );
  }
}

class _StaticStarsPainter extends CustomPainter {
  static const List<Offset> _stars = [
    Offset(0.18, 0.22),
    Offset(0.34, 0.58),
    Offset(0.52, 0.30),
    Offset(0.68, 0.74),
    Offset(0.80, 0.40),
    Offset(0.26, 0.80),
    Offset(0.62, 0.18),
    Offset(0.46, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final s in _stars) {
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        0.9,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StaticStarsPainter old) => false;
}
